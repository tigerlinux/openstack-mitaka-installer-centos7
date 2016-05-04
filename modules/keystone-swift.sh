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
	echo "DB Proccess OK. Let's continue"
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
	echo "Keystone Proccess not completed. Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/keystone-extra-idents ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi


source $keystone_fulladmin_rc_file

echo ""
echo "Creating SWIFT Identities"
echo ""

echo "Swift User:"
openstack user create --domain $keystonedomain --password $swiftpass --email $swiftemail $swiftuser

echo "Swift Role:"
openstack role add --project $keystoneservicestenant --user $swiftuser $keystoneadminuser

echo "Swift Service:"
openstack service create \
        --name $swiftsvce \
        --description "OpenStack Object Storage" \
        object-store

echo "Swift Endpoints:"

openstack endpoint create --region $endpointsregion \
	object-store public http://$swifthost:8080/v1/AUTH_%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	object-store internal http://$swifthost:8080/v1/AUTH_%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	object-store admin http://$swifthost:8080/v1

echo "Ready"

echo ""
echo "SWIFT Identities Created"
echo ""
