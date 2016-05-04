#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack MITAKA for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "DB Proccess OK. Let's Continue"
	echo ""
else
	echo ""
	echo "DB Proccess not completed. Aborting !"
	echo ""
	exit 0
fi


if [ -f /etc/openstack-control-script-config/keystone-installed ]
then
	echo ""
	echo "Keystone Proccess OK. Let's continue"
	echo ""
else
	echo ""
	echo "DB Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-extra-idents ]
then
	echo ""
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi


source $keystone_fulladmin_rc_file

echo ""
echo "Creating GLANCE Identities"
echo ""

echo "Glance User"
openstack user create --domain $keystonedomain --password $glancepass --email $glanceemail $glanceuser

echo "Glance Role"
openstack role add --project $keystoneservicestenant --user $glanceuser $keystoneadminuser

echo "Glance Service"
openstack service create \
        --name $glancesvce \
        --description "OpenStack Image service" \
	image

echo "Glance Endpoints"

openstack endpoint create --region $endpointsregion \
	image public http://$glancehost:9292

openstack endpoint create --region $endpointsregion \
	image internal http://$glancehost:9292

openstack endpoint create --region $endpointsregion \
	image admin http://$glancehost:9292

echo ""
echo "GLANCE Identities DONE"
echo ""

