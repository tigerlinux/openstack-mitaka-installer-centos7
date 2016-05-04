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
	echo "This module was alread completed. Exiting !"
	echo ""
	exit 0
fi

source $keystone_fulladmin_rc_file

echo ""
echo "Creating Extra Tenants"
echo ""

for myidentityname in $extratenants
do
        openstack project create --domain $keystonedomain $myidentityname
        openstack user create \
		--domain $keystonedomain \
                --password "$myidentityname-$extratenantbasepass" \
                --email "$myidentityname@$domainextratenants" \
		--project $myidentityname \
                $myidentityname
	openstack role add --project $myidentityname --user $myidentityname $keystonememberrole
	openstack role add --project $myidentityname --user $myidentityname $keystoneuserrole
	if [ $heatinstall == "yes" ]
	then
		openstack role add --project $myidentityname --user $myidentityname $heat_stack_owner
	fi
done

sync
sleep 5
sync

echo ""
echo "Extra Tenants Module DONE !!"
echo ""

