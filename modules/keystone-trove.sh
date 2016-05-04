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
	echo "Can't Access my config file. Aborting !"
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
	echo "This module was already installed. Exiting !"
	echo ""
	exit 0
fi

source $keystone_fulladmin_rc_file

echo ""
echo "Creating TROVE Identities"
echo ""

echo "Trove User:"
openstack user create --domain $keystonedomain --password $trovepass --email $troveemail $troveuser

echo "Trove Tenant:"
openstack project create --domain $keystonedomain $troveuser

echo "Adding Roles on tenants: $troveuser and $keystoneservicestenant"
openstack role add --project $keystoneservicestenant --user $troveuser $keystoneadminuser
openstack role add --project $troveuser --user $troveuser $keystoneadminuser

echo "Trove Services:"
openstack service create \
        --name $trovesvce \
        --description "Database Service" \
        database

echo "Trove Endpoints"

openstack endpoint create --region $endpointsregion \
	database public "http://$trovehost:8779/v1.0/\$(tenant_id)s"

openstack endpoint create --region $endpointsregion \
	database internal "http://$trovehost:8779/v1.0/\$(tenant_id)s"

openstack endpoint create --region $endpointsregion \
	database admin "http://$trovehost:8779/v1.0/\$(tenant_id)s"

echo "Ready"

echo ""
echo "TROVE Identities Created"
echo ""

