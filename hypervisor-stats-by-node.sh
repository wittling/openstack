#!/bin/bash -
#title           :hypervisor-stats-by-node.sh
#description     :Generate stats rollup on a hypervisor by hypervisor basis 
#author          :Wittling
#date            :2019-11-25
#version         :2.1
#usage           :bash hypervisor-stats-by-node.sh
#todo            : 
#revisions          :1.0 - Initial Version. Writes out 2 files - detail and summary.
#revisions          :2.0 - Add storage and VM counts. 
#revisions          :2.1 - Jettison the unncessary summary - everything in detail.
#==============================================================================
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

usage() { echo "Usage: $0 -e [P6|DUKE|DVTC]" 1>&2; exit 1; }

while getopts ":e:" opt; do
    case "${opt}" in
        e)
            ENVMT=${OPTARG}
            ;;
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${ENVMT}" ]; then
    usage
else
   if [ ${ENVMT} != "P6" -a ${ENVMT} != "DUKE" -a ${ENVMT} != "DVTC" ]; then
      echo "ERR: Incorrect environment passed in"
      usage
   fi
fi

if [ -f "/root/keystonercv3" ]; then
   source /root/keystonercv3
else
   echo "Enter your path to your OpenStack rc file: \c"
   read path
   if [ -f ${path} ]; then
      source ${path}
   else
      echo "ERR: RC File Not Found"
   fi
fi

rundate=`date +%Y-%m-%d`
RAWFILE="hypervisor-stats-bynode-${ENVMT}-${rundate}-detailed.csv"
DETAILFILE="hypervisor-stats-bynode-${ENVMT}-${rundate}-detailed-addl.csv"
SUMFILE="hypervisor-stats-bynode-${ENVMT}-${rundate}-summarized.csv"

printdetailrow()
{
   if [ $# -ne 12 ]; then
      echo "ERR: Invalid Number of Parameters $#"
      exit 1
   else
      echo "$1,$2,$3,$4,$5,$6,$7,$8,$9,${10},${11},${12}" >>${DETAILFILE}
   fi
} 

# Go ahead and generate a csv file.
openstack hypervisor list --long --quote none -f csv >${RAWFILE}

# This is another way to skin the cat WITHOUT the csv file. But pounded out for now.
#readarray -t  < <(openstack hypervisor list | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
IFS=','
readarray -t hypervisorstats < ${RAWFILE}
#hypervisorstats=("${hypervisorstats[@]#*,}")
#hypervisorstats=("${hypervisorstats[@]%%,*}")

FIRSTLINE=1
NODECNT=0
TOTVMCNT=0
TCPUCNT=0
ACPUCNT=0
TMEMCNT=0
AMEMCNT=0

CNT=0
echo "Calculating Totals..."
for line in "${hypervisorstats[@]}"
do
   read -r -a fields <<<"${line}"
   if [ ${CNT} -eq 0 ]; then
      # save the header row. we will need it.
      if [ ${fields[1]} == "Hypervisor Hostname" ]; then
         hdrarr=( "${fields[@]}" "DSK USED" "TOT DSK" "VMS")
         >${DETAILFILE}
         printdetailrow ${hdrarr[@]}
      else
         echo "ERR: RAWFILE unrecognized format."
         exit 1
      fi
   elif [ ${CNT} -gt 0 ]; then
      # openstack hypervisor list prints out a long quoted FQDN which does NOT work with host show. 
      # grab the short name. awk, sed, million ways to skin a cat. we will use cut.
      MNEMONIC=`echo "${fields[1]}" | cut -d\. -f1`

      # roll up some stats hypervisor by hypervisor
      (( TCPUCNT += ${fields[5]} ))
      (( ACPUCNT += ${fields[6]} ))
      (( TMEMCNT += ${fields[7]} ))
      (( AMEMCNT += ${fields[8]} ))

      # no storage stats unforatunately. lets get some.
      openstack host show ${MNEMONIC} --quote none -f csv >hostshow-${MNEMONIC}.csv
      readarray -t hostshowstats < hostshow-${MNEMONIC}.csv
      for showstatsline in "${hostshowstats[@]}"
      do
        read -r -a showstatsfields <<<"${showstatsline}"
        if [ ${showstatsfields[1]} == "(total)" ]; then
           HYPDSKTOT=${showstatsfields[4]}
        elif [ ${showstatsfields[1]} == "(used_now)" ]; then
           HYPDSKUSED=${showstatsfields[4]}
        fi
      done

      # apparently this fails when using the id so we will use the name instead.
      #VMCNT=`nova hypervisor-servers ${fields[0]} | grep instance | wc -l`
      # the API call to OpenStack fails a validation if you have quotes so trim them out.
      VMCNT=`nova hypervisor-servers ${fields[1]} | grep instance | wc -l`
      ((TOTVMCNT += VMCNT))

      echo "hypervisor: ${MNEMONIC},${fields[5]},${fields[6]},${fields[7]},${fields[8]},${HYPDSKUSED},${HYPDSKTOT},${VMCNT}"
      # replace the array sub 1 with the shortened name
      fields[1]=${MNEMONIC}
      hdrarr=( "${fields[@]}" ${HYPDSKUSED} ${HYPDSKTOT} ${VMCNT})
      printdetailrow ${hdrarr[@]}
      # clean up after ourselves
      rm hostshow-${MNEMONIC}.csv
   fi
   (( CNT += 1 ))
done
# now back the header row off the count
(( CNT -= 1 ))

# sort the final file by host. looks nicer.
# sort --field-separator=',' --key=2 ${DETAILFILE} >${RAWFILE}
# Ooops. Forgot about the header row. This dude (George Vasiliou) has the brilliant solution.
head -n 1 ${DETAILFILE} >${RAWFILE}
sort --field-separator=',' --key=2 <(tail -n+2 ${DETAILFILE}) >>${RAWFILE}
rm -f ${DETAILFILE}

# Now write out the final tallies
#if [ -f ${SUMFILE} ]; then
#   >${SUMFILE}
#fi
#
#RATIOCPU="0:0"
# First make sure we have a valid divisor
#if [ ${TCPUCNT} -ne 0 ]; then
#   RATIO=$((ACPUCNT / TCPUCNT))
#   RATIOCPU="${RATIO}:1"
#else
#   RATIOCPU="${ACPUCNT}:0"
#fi

#if [ ${TMEMCNT} -ne 0 ]; then
#   RATIO=$((AMEMCNT / TMEMCNT))
#   RATIOMEM="${RATIO}:1"
#else
#   RATIOMEM="${AMEMCNT}:0"
#fi

#echo "Hypervisors,VMs,vCPU Used,vCPU Allocated,Mem Used,Mem Allocated, vCPU Ratio,Mem Ratio" >>${SUMFILE}
#echo "${CNT},${TOTVMCNT},${TCPUCNT},${ACPUCNT},${TMEMCNT},${AMEMCNT},${RATIOCPU},${RATIOMEM}" >>${SUMFILE}
chown mwittlin:mwittlin *.csv
