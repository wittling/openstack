#!/bin/bash -       
#title           :list-project-instances.sh
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
   # Prompt the user to select one of the lines.
   echo "Please select a project or x to Exit:"
   select choice in "${lines[@]}"; do
     [[ -n $choice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
     break # valid choice was made; exit prompt.
   done

   # Split the chosen line into ID and serial number.
   read -r id prjname unused <<<"$choice"
   echo "id: [$id]; projname: [$prjname]"

   # Present all of the instances back to user and repeat loop so you can do a server show.
   #openstack server list --project $id
   readarray -t serverlines < <(openstack server list --project $id | awk -F'|' '/\|/ && !/ID/{print $2$3}' )
   if [ ${#serverlines[@]} -eq 0 ]; then
      echo "OpenStack returned no instances for project ${id}."
      exit 1
   else
      # Prompt the user to select one of the lines.
      echo "Please select a server to show it:"
      select svrchoice in "${serverlines[@]}"; do
        [[ -n $svrchoice ]] || { echo "Invalid choice. Please try again." >&2; continue; }
        break # valid choice was made; exit prompt.
      done

      # Split the chosen line into ID and serial number.
      read -r svrid svrname unused <<<"$svrchoice"

      echo "id: [$svrid]; svrname: [$svrname]"
      openstack server show $svrid
   fi
fi
