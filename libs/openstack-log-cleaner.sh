#!/bin/bash
#
# Unattended installer for OpenStack.
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# OpenStack LOGS cleanup script
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

case $1 in
auto|AUTO)
	echo ""
	echo "Automated cleanup activated"
	echo ""
	;;
*)
	echo ""
	echo "This script will clean all OpenStack related LOGS"
	echo -n "Do you wish to continue ? [y/n]:"
	read -n 1 answer
	echo ""
	case $answer in
	y|Y)
		echo ""
		echo "Cleaning all openstack logs"
		echo ""
		;;
	*)
		echo ""
		echo "Aborted by user request !!!"
		echo ""
		exit 0
		;;
	esac
	;;
esac

logdirs='
	/var/log/swift
	/var/log/glance
	/var/log/cinder
	/var/log/neutron
	/var/log/nova
	/var/log/ceilometer
	/var/log/aodh
	/var/log/horizon
	/var/log/keystone
	/var/log/heat
	/var/log/trove
	/var/log/sahara
	/var/log/manila
	/var/log/designate
'

for logdirectory in $logdirs
do
	if [ -d $logdirectory ]
	then
		echo "Cleaning logs into $logdirectory"
		cd $logdirectory
		loglist=`ls *.log 2>/dev/null`
		for mylogfile in $loglist
		do
			echo "Cleaning log file: $mylogfile"
			echo "" > $mylogfile
		done
	fi
done

echo ""
echo "Logs cleaned"
echo ""
