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
	echo "Keystone Proccess OK. Let's Continue"
	echo ""
else
	echo ""
	echo "Keystone Proccess not complete. Aborting !"
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
echo "Creating MANILA Identities"
echo ""

echo "Manila User:"
openstack user create --domain $keystonedomain --password $manilapass --email $manilaemail $manilauser

echo "Manila Role"
openstack role add --project $keystoneservicestenant --user $manilauser $keystoneadminuser

echo "Manila Services V1 and V2:"
openstack service create \
	--name $manilasvcev1 \
	--description "OpenStack Shared File Systems V1" \
	share

openstack service create \
	--name $manilasvcev2 \
	--description "OpenStack Shared File Systems V2" \
	sharev2

echo "Manila Endpoints:"

openstack endpoint create --region $endpointsregion \
	share public http://$manilahost:8786/v1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	share internal http://$manilahost:8786/v1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	share admin http://$manilahost:8786/v1/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	sharev2 public http://$manilahost:8786/v2/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	sharev2 internal http://$manilahost:8786/v2/%\(tenant_id\)s

openstack endpoint create --region $endpointsregion \
	sharev2 admin http://$manilahost:8786/v2/%\(tenant_id\)s


echo "Ready"

echo ""
echo "MANILA Identities Created"
echo ""

