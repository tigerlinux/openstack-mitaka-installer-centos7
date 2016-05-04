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

if [ -f /etc/openstack-control-script-config/sahara-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We install sahara related packages and dependencies
#

echo ""
echo "Installing Sahara Packages"

yum install -y openstack-sahara \
	openstack-sahara-api \
	openstack-sahara-common \
	openstack-sahara-engine \
	python-saharaclient \
	openstack-utils \
	openstack-selinux

echo "Done"
echo ""

source $keystone_admin_rc_file

#
# By using python based "ini" config tools, we proceed to configure Sahara
#

echo ""
echo "Configuring Sahara"
echo ""

#
# This seems overkill, but we had found more than once of this setting repeated inside sahara.conf
#

crudini --del /etc/sahara/sahara.conf database connection
crudini --del /etc/sahara/sahara.conf database connection
crudini --del /etc/sahara/sahara.conf database connection
crudini --del /etc/sahara/sahara.conf database connection
crudini --del /etc/sahara/sahara.conf database connection

#
# Database flavor configuration based on our selection inside the installer main config file
#

case $dbflavor in
"mysql")
	crudini --set /etc/sahara/sahara.conf database connection mysql+pymysql://$saharadbuser:$saharadbpass@$dbbackendhost:$mysqldbport/$saharadbname
	;;
"postgres")
	crudini --set /etc/sahara/sahara.conf database connection postgresql+psycopg2://$saharadbuser:$saharadbpass@$dbbackendhost:$psqldbport/$saharadbname
	;;
esac

#
# Main config
#

crudini --set /etc/sahara/sahara.conf DEFAULT debug false
crudini --set /etc/sahara/sahara.conf DEFAULT verbose false
crudini --set /etc/sahara/sahara.conf DEFAULT log_dir /var/log/sahara
crudini --set /etc/sahara/sahara.conf DEFAULT log_file sahara.log
crudini --set /etc/sahara/sahara.conf DEFAULT host $saharahost
crudini --set /etc/sahara/sahara.conf DEFAULT port 8386
crudini --set /etc/sahara/sahara.conf DEFAULT use_neutron true
crudini --set /etc/sahara/sahara.conf DEFAULT use_namespaces true
crudini --set /etc/sahara/sahara.conf DEFAULT os_region_name $endpointsregion
crudini --set /etc/sahara/sahara.conf DEFAULT control_exchange openstack
 
#
# Keystone Sahara Config
#
 
crudini --set /etc/sahara/sahara.conf keystone_authtoken signing_dir /tmp/keystone-signing-sahara
crudini --set /etc/sahara/sahara.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/sahara/sahara.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/sahara/sahara.conf keystone_authtoken auth_type password
crudini --set /etc/sahara/sahara.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/sahara/sahara.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/sahara/sahara.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/sahara/sahara.conf keystone_authtoken username $saharauser
crudini --set /etc/sahara/sahara.conf keystone_authtoken password $saharapass
crudini --set /etc/sahara/sahara.conf keystone_authtoken region_name $endpointsregion
crudini --set /etc/sahara/sahara.conf keystone_authtoken memcached_servers $keystonehost:11211
 
crudini --set /etc/sahara/sahara.conf oslo_concurrency lock_path "/var/oslock/sahara"
 
mkdir -p /var/oslock/sahara
chown -R sahara.sahara /var/oslock/sahara


#
# Message Broker config for sahara. Again, based on our flavor selected inside the installer config file
#

case $brokerflavor in
"qpid")
        crudini --set /etc/sahara/sahara.conf DEFAULT rpc_backend qpid
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_hostname $messagebrokerhost
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_port 5672
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_username $brokeruser
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_password $brokerpass
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_heartbeat 60
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_protocol tcp
	crudini --set /etc/sahara/sahara.conf oslo_messaging_qpid qpid_tcp_nodelay True
        ;;
 
"rabbitmq")
        crudini --set /etc/sahara/sahara.conf DEFAULT rpc_backend rabbit
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_password $brokerpass
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_userid $brokeruser
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_port 5672
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_use_ssl false
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_max_retries 0
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_retry_interval 1
	crudini --set /etc/sahara/sahara.conf oslo_messaging_rabbit rabbit_ha_queues false
        ;;
esac

if [ $ceilometerinstall == "yes" ]
then
        crudini --set /etc/sahara/sahara.conf oslo_messaging_notifications enable true
        crudini --set /etc/sahara/sahara.conf oslo_messaging_notifications driver messagingv2
fi

mkdir -p /var/log/sahara
echo "" > /var/log/sahara/sahara.log
chown -R sahara.sahara /var/log/sahara /etc/sahara

echo ""
echo "Sahara Configured"
echo ""

#
# With the configuration done, we proceed to provision/update Sahara database
#

echo ""
echo "Provisioning Sahara DB"
echo ""

sahara-db-manage --config-file /etc/sahara/sahara.conf upgrade head

chown -R sahara.sahara /var/log/sahara /etc/sahara /var/oslock/sahara

echo ""
echo "Done"
echo ""

#
# Then we apply IPTABLES rules and start/enable Sahara services
#

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 8386 -j ACCEPT
service iptables save

echo "Done"

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/sahara/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo ""
echo "Starting Services"
echo ""

systemctl start openstack-sahara-all
systemctl enable openstack-sahara-all

#
# Finally, we perform a package installation check. If we fail this, we stop the main installer
# from this point.
#

testsahara=`rpm -qi openstack-sahara|grep -ci "is not installed"`
if [ $testsahara == "1" ]
then
	echo ""
	echo "Sahara Installation Failed. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/sahara-installed
	date > /etc/openstack-control-script-config/sahara
fi


echo ""
echo "Sahara Installed and Configured"
echo ""



