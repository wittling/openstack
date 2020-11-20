#!/bin/bash -
#title           :hypervisor-stats-summary.sh
#description     :Generate stats for all hypervisors on the OpenStack Cloud
#author          :Wittling
#date            :2019-11-25
#version         :0.1
#usage           :bash hypervisor-stats-summary.sh
#notes           :this is a report that the NFV Cloud Management Team likes to get
#                :NOTE: THIS REPORT WILL NEED TO BE COMBINED WITH THE OTHER CLOUDS!!!
#todo            :
#revisions
#author          :
#author          :
#author          :
#==============================================================================
# nova hypervisor stats show command:
# Field                 Value
# count                 - number of hypervisors in enabled state (not disabled)
#
# current_workload      - sum of boot, reboot, migrate, resize operations. 
# NOTE: see https://github.com/openstack/nova/blob/master/nova/compute/stats.py#L45 for how this is calculated in source code.
#
# disk_available_least  - dependent on virt driver, disk image backing file, and as reliable as a one-armed guitar player.
#
# free_disk_gb          - theoretically should be Sigma(local_gb - local_gb_used) for all hypervisor hosts
#
# free_ram_mb           - theoretically should be Sigm(memory_mb - memory_mb_used) for all hypervisor hosts
#
# local_gb              - amount of space, in GB, available for ephemeral disk images on the hypervisor hosts. 
# NOTE: if shared storage is used, this value is as useful as having two left feet.
#
# local_gb_used         - the amount of storage used for ephemeral disk images of instances on the hypervisor hosts.
# NOTE: if the instances are boot-from-volume, this number is about as valuable as a three-dollar bill.
#
# memory_mb             - the total amount of RAM the hypervisor hosts have. 
# NOTE: this does not take into account the amount of reserved memory the host might have configured
#
# memory_mb_used        - the total amount of RAM that has been allocated to VMs
#
# running_vms           - total number of VMs that are not in a state of DELETED, or SHELVED_OFFLOADED states.
#
# vcpus                 - total amount of cpu core-threads across all hypervisor hosts that OpenStack has access to.
# NOTE: If cpu cores have been reserved (i.e. for OpenContrail) they do not show up here.
#
# vcpus_used            - total number of vCPUs allocated to guests regardless of VM state across hypervisor hosts.
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
SUMFILE="hypervisor-stats-summary-${ENVMT}-${rundate}.csv"

echo "Gathering Hypervisor Statistics..."
# we do not need ALL of the stats that are dumped out. So we will do an awk filter and suppress the ones we do not want.
# use the pipe as delimeter and ignore the stats we do not want.
readarray -t  hypervisorstats < <(openstack hypervisor stats show | awk -F'|' '/\|/ && !/(Field|current|disk|local)/{print $1$2$3}' )
# This is what we should have now after filtering
# count                 23
# free_ram_mb           10501011
# memory_mb             11801327
# memory_mb_used        1300316
# running_vms           76
# vcpus                 1068
# vcpus_used            337
NODECNT=`echo ${hypervisorstats[0]} | awk '{print $2}'`
VMCNT=`echo ${hypervisorstats[4]} | awk '{print $2}'`
USEDCPU=`echo ${hypervisorstats[6]} | awk '{print $2}'`
CPUALLOC=`echo ${hypervisorstats[5]} | awk '{print $2}'`
USEDMEM=`echo ${hypervisorstats[3]} | awk '{print $2}'`
USEDMEM=$((${USEDMEM} / 1024))
MEMALLOC=`echo ${hypervisorstats[2]} | awk '{print $2}'`
MEMALLOC=$((${MEMALLOC} / 1024))

RATIOCPU="0:0"
# First make sure we have a valid divisor
if [ ${USEDCPU} -ne 0 ]; then
   RATIO=$((CPUALLOC / USEDCPU))
   RATIOCPU="${RATIO}:1"
else
   RATIOCPU="${CPUALLOC}:0"
fi

if [ ${USEDMEM} -ne 0 ]; then
   RATIO=$((MEMALLOC / USEDMEM))
   RATIOMEM="${RATIO}:1"
else
   RATIOMEM="${MEMALLOC}:0"
fi

echo "NODECNT: ${NODECNT}"
echo "VMCNT: ${VMCNT}"
echo "USEDCPU: ${USEDCPU}"
echo "ALLOCATEDCPU: ${CPUALLOC}"
echo "CPURATIO: ${RATIOCPU}"
echo "USEDMEM: ${USEDMEM}"
echo "MEMALLOC: ${MEMALLOC}"
echo "MEMRATIO: ${RATIOMEM}"

# Now write out the final tallies
if [ -f ${SUMFILE} ]; then
   >${SUMFILE}
fi

echo "Env,Hypervisors,Running VMs,CPU Used,CPU Allocated,CPU Ratio,Mem Used,Mem Allocated,Mem Ratio"
echo "P6,${NODECNT},${VMCNT},${USEDCPU},${CPUALLOC},${RATIOCPU},${USEDMEM},${MEMALLOC},${RATIOMEM}" 
echo "Env,Hypervisors,Running VMs,CPU Used,CPU Allocated,CPU Ratio,Mem Used,Mem Allocated,Mem Ratio" >${SUMFILE}
echo "P6,${NODECNT},${VMCNT},${USEDCPU},${CPUALLOC},${RATIOCPU},${USEDMEM},${MEMALLOC},${RATIOMEM}" >>${SUMFILE}
