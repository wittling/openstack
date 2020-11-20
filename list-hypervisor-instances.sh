#!/bin/bash -
#title           :list-hypervisor-instances.sh
#description     :OpenStack script to list instances belonging to a specific project.
#author          :Wittling
#date            :2019-11-25
#version         :0.1
#usage           :bash list-project-instances.sh
#notes           :The OpenStack environment variables (i.e. keystonercv3) MUST be sourced for this script to work properly!!!

#todo            : use stack approach and do push pops so that you can go up and down the hierarchy.
#revisions
#author          :
#author          :
#author          :
#==============================================================================
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
readarray -t lines < <(openstack hypervisor list | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
if [ ${#lines[@]} -eq 0 ]; then
   echo "OpenStack returned no hypervisors. Please check your environment settings for this script!"
   exit 1
else
   # Add an x to the end of the array so the user can bail if they want.
   lines+=("Exit")

   while :
   do
      # Prompt the user to select one of the lines.
      echo "Please select a hypervisor:"
      select choice in "${lines[@]}"; do
        # Fix this since it gave the user no clearn way to exit.
        #[[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
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
      read -r hypid hypname unused <<<"$choice"
      echo "hypvervisor id: [$hypid]; hypname: [$hypname]"
   
      # ACHTUNG:
      # I discovered that by using the id to list the instances, it did not actually work consistently so we will use the name.
      # readarray -t serverlines < <(nova hypervisor-servers $hypid | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
      readarray -t serverlines < <(nova hypervisor-servers $hypname | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
      if [ ${#serverlines[@]} -eq 0 ]; then
         echo "OpenStack returned no instances. Please check your environment settings for this script!"
         exit 1
      else
         # Prompt the user to select one of the lines.
         echo "Please select an instance to show it:"
         select svrchoice in "${serverlines[@]}"; do
           [[ -n $svrchoice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
           break # valid choice was made; exit prompt.
         done
   
         # Split the chosen line into ID and serial number.
         read -r svrid svrname unused <<<"$svrchoice"
   
         echo "id: [$svrid]; svrname: [$svrname]"
         readarray -t instancedetails < <(nova show $svrid | awk -F'|' '/\|/ && !/ID/{print $2 $3}' )
         for detail in "${instancedetails[@]}"
         do
            read -r key val <<<"${detail}"
            echo "${key}  -->  ${val}"
         done
      fi
      echo ""
   done
fi
