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
	echo "Can't access my config file"
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
	echo "This module was already completed. Exiting"
	echo ""
	exit 0
fi

source $keystone_fulladmin_rc_file

echo ""
echo "Creating CEILOMETER identities"
echo ""

echo "Ceilometer User:"
openstack user create --domain $keystonedomain --password $ceilometerpass --email $ceilometeremail $ceilometeruser

echo "Ceilometer Role:"
openstack role add --project $keystoneservicestenant --user $ceilometeruser $keystoneadminuser

echo "Ceilometer Service:"
openstack service create \
        --name $ceilometersvce \
        --description "Telemetry" \
        metering

echo "Ceilometer Endpoints:"

openstack endpoint create --region $endpointsregion \
	metering public http://$ceilometerhost:8777

openstack endpoint create --region $endpointsregion \
	metering internal http://$ceilometerhost:8777

openstack endpoint create --region $endpointsregion \
	metering admin http://$ceilometerhost:8777

echo "Creating Role: $keystonereselleradminrole"
openstack role create $keystonereselleradminrole
openstack role add --project $keystoneservicestenant --user $ceilometeruser $keystonereselleradminrole

if [ $ceilometeralarms == "yes" ]
then
	echo "Aodh User:"
	openstack user create --domain $keystonedomain --password $aodhpass --email $aodhemail $aodhuser

	echo "Aodh Role:"
	openstack role add --project $keystoneservicestenant --user $aodhuser $keystoneadminuser

	echo "Aodh Service:"
	openstack service create \
		--name $aodhsvce \
		--description "Telemetry Alarming" \
		alarming

	echo "Aodh Endpoints:"

	openstack endpoint create --region $endpointsregion \
		alarming public http://$ceilometerhost:8042

	openstack endpoint create --region $endpointsregion \
		alarming internal http://$ceilometerhost:8042

	openstack endpoint create --region $endpointsregion \
		alarming admin http://$ceilometerhost:8042
fi

echo "Done"

echo ""
echo "Ceilometer Identities Ready"
echo ""

