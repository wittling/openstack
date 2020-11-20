#!/bin/bash -       
#title           :project-stats.sh
#description     :OpenStack script to list instances belonging to a specific project.
#author		 :Wittling
#date            :2019-11-25
#version         :0.1
#usage		 :bash list-project-instances.sh
#notes           :The OpenStack environment variables (i.e. keystonercv3) MUST be sourced for this script to work properly!!!

#todo            : use  stack approach and do push pops so that you can go up and down the hierarchy.
#revisions
#author          :
#author          :
#author          :
#==============================================================================

# Due to the need to keep diving back to the OpenStack API I felt a Progress Bar 
# was a beneficial thing to have. Let us give some credit to where it is due
# for this nice function that does that math for us.
# This came from github fearside ProgressBar
#
# TODO: I just wish it didnt screw up my vim syntax formatting.
#       But the bug is actually in the vim syntax formatting apparently.
function ProgressBar {
# Process data
    let _progress=(${1}*100/${2}*100)/100
    let _done=(${_progress}*4)/10
    let _left=40-$_done
# Build progressbar string lengths
    _fill=$(printf "%${_done}s")
    _empty=$(printf "%${_left}s")

# 1.2 Build progressbar strings and print the ProgressBar line
# 1.2.1 Output example:                           
# 1.2.1.1 Progress : [########################################] 100%
printf "\rProgress : [${_fill// /#}${_empty// /-}] ${_progress}%%"
}

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
else
   if [ -f /root/keystonercv3 ]; then
      source /root/keystonercv3
   else
       echo "ERR: No OpenStack environment variables to source"
       exit 1
   fi
fi

# Read command output line by line into array ${lines [@]}
# Bash 3.x: use the following instead:
#   IFS=$'\n' read -d '' -ra lines < <(lsblk --nodeps -no name,serial,size | grep "sd")
#readarray -t lines < <(openstack project list | awk -F'|' '/\|/ && !/ID/{print $2$3"\n"}' | cut -d" " -f-2,3-)
readarray -t lines < <(openstack project list | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
if [ ${#lines[@]} -eq 0 ]; then
   echo "OpenStack returned no projects. Please check your environment settings for this script!"
   exit 1
else
   lines+=("Exit")
   while :
   do
      # Prompt the user to select one of the lines.
      echo "Please select a project or choose Exit option:"
      select choice in "${lines[@]}"; do
        # Fix this since it gave the user no clearn way to exit.
        # [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
        # break # valid choice was made; exit prompt.

        if [ -z "${choice}" ]; then
           echo "Invalid choice. Please try again." >&2
           continue
        elif [ "${choice}" == "Exit" ]; then
           echo "Goodbye!"
           exit 0
        else
           break # valid choice was made; exit prompt.
        fi
      done
   
      # Split the chosen line into ID and serial number.
      read -r prjid prjname unused <<<"$choice"
      echo "Selected Project Id: ${prjid}: Project Name: [$prjname]"
      printf "Gathering Statistics..."
      # Present all of the instances back to user and repeat loop so you can do a server show.
      readarray -t serverlines < <(openstack server list --project $prjid | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
      if [ ${#serverlines[@]} -eq 0 ]; then
         echo "OpenStack returned no instances for project ${prjid}."
         echo "----------------------"
         echo "No Resources Consumed."
         echo "----------------------"
      else
         # Get the length of the array for progress indication.
         instances=${#serverlines[@]}
   
         DISKSUM=0
         RAMSUM=0
         VCPUSUM=0
         PROGRESS=0
   
         # We need to grab flavor for each instance then dive down into stats for the flavor
         for instance in "${serverlines[@]}"
         do
            ((PROGRESS ++))
            ProgressBar ${PROGRESS} instances
            read -r -a instancemeta <<<"${instance}"
            instanceid="${instancemeta[0]}"
            #echo "Our InstanceId is: ${instanceid}"
            readarray -t  instancedetails < <(openstack server show ${instanceid} | grep flavor | awk -F'|' '/\|/ && !/ID/{print $2$3}')
            if [ ${#instancedetails[@]} -eq 0 ]; then
               echo "No Instance Details for Instance Id: ${instanceid}."
               exit 1
            else
               # of course there should be only one item since we did a grep on flavor above.
               for item in "${instancedetails[@]}"
               do
                  read -r itemname itemval <<<"${item}"
                  #echo "ItemName: ${itemname} ItemValue: ${itemval}"
                  flavorid=`echo ${itemval} | awk '{print $2}' | tr -d '()'`
                  #echo "Flavor ID: ${flavorid}"
                  # Now we need to get our flavor stats and roll them up.
                  readarray -t  flavordetails < <(openstack flavor show ${flavorid} | awk -F'|' '/\|/ && !/ID/{print $2$3}')
                  if [ ${#flavordetails[@]} -eq 0 ]; then
                     echo "No Flavor Details for Flavor Id: ${flavorid}."
                     exit 1
                  else
                     for aspect in "${flavordetails[@]}"
                     do
                        read -r aspectname aspectval <<<"${aspect}"
                        case "${aspectname}" in
                           "disk")
                                ((DISKSUM += ${aspectval}))     
                                ;;
                           "ram")
                                ((RAMSUM += ${aspectval}))     
                                ;;
                           "vcpus")
                                ((VCPUSUM += ${aspectval}))     
                                ;;
                        esac
                     done
                  fi
               done 
            fi
         done
         printf "\n"
         echo "-----------------------------------------------------------------------------------"
         echo "VCPUSUM: ${VCPUSUM} RAMSUM: ${RAMSUM}G DISKSUM: ${DISKSUM}G INSTANCES: ${instances}"
         echo "-----------------------------------------------------------------------------------"
      fi
   done
fi
