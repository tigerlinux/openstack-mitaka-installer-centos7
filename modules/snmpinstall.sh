#!/bin/bash
#
# Unattended/SemiAutomatted OpenStack Installer
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
# OpenStack MITAKA for Centos 7
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# First, we source our config file and verify that some important proccess are 
# already completed.
#

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

if [ -f /etc/openstack-control-script-config/snmp-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# If we find a pre-existent snmpd.conf, we back it up
#

if [ -f /etc/snmp/snmpd.conf ]
then
	snmpdconfpresent="yes"
	cp -v /etc/snmp/snmpd.conf /etc/snmp/snmpd.conf.pre-openstack
else
	snmpdconfpresent="no"
fi

#
# We proceed to install snmp packages
#

echo ""
echo "Installing monitoring support"
echo ""

yum -y install net-snmp-utils net-snmp net-snmp-libs virt-top bc

cp -v ./libs/snmp/scripts/* /usr/local/bin/
chmod a+x /usr/local/bin/*.sh

cp -v ./libs/snmp/crontab/openstack-monitor.crontab /etc/cron.d/
chmod 644 /etc/cron.d/openstack-monitor.crontab
service crond reload

#
# If we found an already present snmpd.conf, we use our complete file, else, we
# just attach the body with our variables
#

case $snmpdconfpresent in
yes)
	cat ./libs/snmp/conf/snmpd.conf.body >> /etc/snmp/snmpd.conf
	;;
no)
	cat ./libs/snmp/conf/snmpd.conf.header > /etc/snmp/snmpd.conf
	cat ./libs/snmp/conf/snmpd.conf.body >> /etc/snmp/snmpd.conf
	;;
esac

service snmpd restart

#
# Finally, we add IPTABLES rules for SNMP
#

echo ""
echo "Applying IPTABLES rules"
echo ""

iptables -I INPUT -p udp -m udp --dport 161 -j ACCEPT
iptables -I INPUT -p tcp -m tcp --dport 161 -j ACCEPT
service iptables save

date > /etc/openstack-control-script-config/snmp
date > /etc/openstack-control-script-config/snmp-installed

echo ""
echo "SNMP Monitoring Support INSTALLED !"
echo ""
