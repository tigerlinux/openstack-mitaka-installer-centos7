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
echo "Creating DESIGNATE Identities"
echo ""

echo "Designate User:"
openstack user create --domain $keystonedomain --password $designatepass --email $designateemail $designateuser

echo "Designate Role"
openstack role add --project $keystoneservicestenant --user $designateuser $keystoneadminuser

echo "Designate Services V1 and V2:"
openstack service create \
	--name $designatesvcev1 \
	--description "OpenStack DNSaaS V1" \
	dns

openstack service create \
	--name $designatesvcev2 \
	--description "OpenStack DNSaaS V2" \
	dnsv2

echo "Designate Endpoints:"

openstack endpoint create --region $endpointsregion \
	dns public http://$designatehost:9001

openstack endpoint create --region $endpointsregion \
	dns internal http://$designatehost:9001

openstack endpoint create --region $endpointsregion \
	dns admin http://$designatehost:9001

openstack endpoint create --region $endpointsregion \
	dnsv2 public http://$designatehost:9001

openstack endpoint create --region $endpointsregion \
	dnsv2 internal http://$designatehost:9001

openstack endpoint create --region $endpointsregion \
	dnsv2 admin http://$designatehost:9001


echo "Ready"

echo ""
echo "DESIGNATE Identities Created"
echo ""

