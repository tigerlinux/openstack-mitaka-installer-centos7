#!/bin/bash
#
# Unattended installer for OpenStack
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Instance CPU Metric report Script
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

mykeystonefile="/root/keystonerc_admin"

source $mykeystonefile

if [ ! -z $1 ]
then

	case $1 in
	all)
		for uuid in `openstack server list --format=csv --all-projects 2>/dev/null|grep -v ID|cut -d\" -f2`; do echo "Instance:$uuid"; ceilometer statistics --meter cpu_util --query resource=$uuid -a min -a avg -a max;echo "";done
		;;
	min|max|avg)
		for uuid in `openstack server list --format=csv --all-projects 2>/dev/null|grep -v ID|cut -d\" -f2`; do echo "Instance:$uuid"; ceilometer statistics --meter cpu_util --query resource=$uuid -a $1;echo "";done
		;;
	*)
		echo ""
		echo "Valid options: all, min, max or avg"
		echo ""
		;;
	esac
else
	for uuid in `openstack server list --format=csv --all-projects 2>/dev/null|grep -v ID|cut -d\" -f2`; do echo "Instance:$uuid"; ceilometer statistics --meter cpu_util --query resource=$uuid -a min -a avg -a max;echo "";done
fi
