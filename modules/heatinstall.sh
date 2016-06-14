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

if [ -f /etc/openstack-control-script-config/heat-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We proceed to install HEAT Packages
#

echo ""
echo "Installing HEAT Packages"

yum install -y openstack-heat-api \
	openstack-heat-api-cfn \
	openstack-heat-common \
	python-heatclient \
	openstack-heat-engine \
	openstack-heat-templates \
	openstack-utils \
	openstack-selinux

yum -y install python-zaqarclient python-manilaclient python-mistralclient

# pip install python-mistralclient
# pip install python-magnumclient
# yum -y install python2-keystoneauth1

echo "Done"
echo ""

source $keystone_admin_rc_file

echo ""
echo "Configuring HEAT"
echo ""

#
# By using python based tools, we proceed to configure heat.
#


if [ ! -f /etc/heat/api-paste.ini ]
then
	cat /usr/share/heat/api-paste-dist.ini > /etc/heat/api-paste.ini
fi

if [ ! -f /etc/heat/heat.conf ]
then
	cat /usr/share/heat/heat-dist.conf > /etc/heat/heat.conf
fi

chown -R heat.heat /etc/heat

echo "#" >> /etc/heat/heat.conf


case $dbflavor in
"mysql")
	crudini --set /etc/heat/heat.conf database connection mysql+pymysql://$heatdbuser:$heatdbpass@$dbbackendhost:$mysqldbport/$heatdbname
	;;
"postgres")
	crudini --set /etc/heat/heat.conf database connection postgresql+psycopg2://$heatdbuser:$heatdbpass@$dbbackendhost:$psqldbport/$heatdbname
	;;
esac

crudini --set /etc/heat/heat.conf database retry_interval 10
crudini --set /etc/heat/heat.conf database idle_timeout 3600
crudini --set /etc/heat/heat.conf database min_pool_size 1
crudini --set /etc/heat/heat.conf database max_pool_size 10
crudini --set /etc/heat/heat.conf database max_retries 100
crudini --set /etc/heat/heat.conf database pool_timeout 10
crudini --set /etc/heat/heat.conf database backend heat.db.sqlalchemy.api
 
crudini --set /etc/heat/heat.conf DEFAULT host $heathost
crudini --set /etc/heat/heat.conf DEFAULT debug false
crudini --set /etc/heat/heat.conf DEFAULT verbose false
crudini --set /etc/heat/heat.conf DEFAULT log_dir /var/log/heat
 
crudini --set /etc/heat/heat.conf DEFAULT heat_metadata_server_url http://$heathost:8000
crudini --set /etc/heat/heat.conf DEFAULT heat_waitcondition_server_url http://$heathost:8000/v1/waitcondition
crudini --set /etc/heat/heat.conf DEFAULT heat_watch_server_url http://$heathost:8003
crudini --set /etc/heat/heat.conf DEFAULT heat_stack_user_role $heat_stack_user_role

crudini --set /etc/heat/heat.conf DEFAULT use_syslog False
 
crudini --set /etc/heat/heat.conf heat_api_cloudwatch bind_host 0.0.0.0
crudini --set /etc/heat/heat.conf heat_api_cloudwatch bind_port 8003
 
crudini --set /etc/heat/heat.conf heat_api bind_host 0.0.0.0
crudini --set /etc/heat/heat.conf heat_api bind_port 8004

#
# Keystone Authentication
#
crudini --set /etc/heat/heat.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/heat/heat.conf keystone_authtoken username $heatuser
crudini --set /etc/heat/heat.conf keystone_authtoken password $heatpass
# crudini --set /etc/heat/heat.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/heat/heat.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/heat/heat.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/heat/heat.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/heat/heat.conf keystone_authtoken signing_dir /tmp/keystone-signing-heat
# crudini --set /etc/heat/heat.conf keystone_authtoken auth_version v3
crudini --set /etc/heat/heat.conf keystone_authtoken auth_type password
# crudini --set /etc/heat/heat.conf keystone_authtoken auth_section keystone_authtoken
# crudini --set /etc/heat/heat.conf keystone_authtoken memcached_servers $keystonehost:11211
#
# crudini --set /etc/heat/heat.conf keystone_authtoken identity_uri http://$keystonehost:35357
# crudini --set /etc/heat/heat.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
# crudini --set /etc/heat/heat.conf keystone_authtoken admin_user $heatuser
# crudini --set /etc/heat/heat.conf keystone_authtoken admin_password $heatpass
#
crudini --del /etc/heat/heat.conf keystone_authtoken auth_uri
crudini --del /etc/heat/heat.conf keystone_authtoken auth_version
crudini --del /etc/heat/heat.conf keystone_authtoken auth_section
crudini --del /etc/heat/heat.conf keystone_authtoken memcached_servers
crudini --del /etc/heat/heat.conf keystone_authtoken identity_uri
crudini --del /etc/heat/heat.conf keystone_authtoken admin_tenant_name
crudini --del /etc/heat/heat.conf keystone_authtoken admin_user
crudini --del /etc/heat/heat.conf keystone_authtoken admin_password
#
crudini --del /etc/heat/heat.conf keystone_authtoken auth_host
crudini --del /etc/heat/heat.conf keystone_authtoken auth_port
crudini --del /etc/heat/heat.conf keystone_authtoken auth_protocol
#
# crudini --set /etc/heat/heat.conf trustee project_name $keystoneservicestenant
crudini --set /etc/heat/heat.conf trustee username $heatuser
crudini --set /etc/heat/heat.conf trustee password $heatpass
# crudini --set /etc/heat/heat.conf trustee auth_uri http://$keystonehost:5000
crudini --set /etc/heat/heat.conf trustee auth_url http://$keystonehost:35357
crudini --set /etc/heat/heat.conf trustee project_domain_name $keystonedomain
crudini --set /etc/heat/heat.conf trustee user_domain_name $keystonedomain
# crudini --set /etc/heat/heat.conf trustee signing_dir /tmp/keystone-signing-heat
# crudini --set /etc/heat/heat.conf trustee auth_version v3
crudini --set /etc/heat/heat.conf trustee auth_plugin password
#
# crudini --set /etc/heat/heat.conf trustee identity_uri http://$keystonehost:35357
# crudini --set /etc/heat/heat.conf trustee admin_tenant_name $keystoneservicestenant
# crudini --set /etc/heat/heat.conf trustee admin_user $heatuser
# crudini --set /etc/heat/heat.conf trustee admin_password $heatpass
#
crudini --del /etc/heat/heat.conf trustee project_name
crudini --del /etc/heat/heat.conf trustee auth_uri
crudini --del /etc/heat/heat.conf trustee signing_dir
crudini --del /etc/heat/heat.conf trustee auth_version
crudini --del /etc/heat/heat.conf trustee identity_uri
crudini --del /etc/heat/heat.conf trustee admin_tenant_name
crudini --del /etc/heat/heat.conf trustee admin_user
crudini --del /etc/heat/heat.conf trustee admin_password
#
crudini --set /etc/heat/heat.conf clients_keystone auth_uri http://$keystonehost:35357
crudini --set /etc/heat/heat.conf ec2authtoken auth_uri http://$keystonehost:5000/v2.0/ec2tokens
crudini --set /etc/heat/heat.conf clients_heat url "http://$heathost:8004/v1/%(tenant_id)s"
#
# End of Keystone Auth Section
#
 
crudini --set /etc/heat/heat.conf DEFAULT control_exchange openstack

case $brokerflavor in
"qpid")
	crudini --set /etc/heat/heat.conf DEFAULT rpc_backend qpid
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_hostname $messagebrokerhost
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_port 5672
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_username $brokeruser
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_password $brokerpass
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_heartbeat 60
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_protocol tcp
	crudini --set /etc/heat/heat.conf oslo_messaging_qpid qpid_tcp_nodelay True
	;;
 
"rabbitmq")
	crudini --set /etc/heat/heat.conf DEFAULT rpc_backend rabbit
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_password $brokerpass
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_userid $brokeruser
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_port 5672
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_use_ssl false
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_max_retries 0
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_retry_interval 1
	crudini --set /etc/heat/heat.conf oslo_messaging_rabbit rabbit_ha_queues false
	;;
esac
 
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin $stack_domain_admin
crudini --set /etc/heat/heat.conf DEFAULT stack_domain_admin_password $stack_domain_admin_password
crudini --set /etc/heat/heat.conf DEFAULT stack_user_domain_name $stack_user_domain_name

if [ $ceilometerinstall == "yes" ]
then
        crudini --set /etc/heat/heat.conf oslo_messaging_notifications driver messagingv2
fi
 
echo ""
echo "Heat Configured"
echo ""


#
# We proceed to provision/update HEAT Database
#

echo ""
echo "Provisioning heat DB"
echo ""

chown -R heat.heat /var/log/heat /etc/heat
su -s /bin/sh -c "heat-manage db_sync" heat
chown -R heat.heat /etc/heat /var/log/heat

echo ""
echo "Done"
echo ""

#
# We proceed to apply IPTABLES rules and start/enable Heat services
#

echo ""
echo "Applying IPTABLES Rules"

iptables -A INPUT -p tcp -m multiport --dports 8000,8004 -j ACCEPT
service iptables save

echo "Done"

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/heat/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo ""
echo "Starting HEAT"
echo ""

servicelist='
	openstack-heat-api
	openstack-heat-api-cfn
	openstack-heat-engine
'

for myservice in $servicelist
do
	echo "Starting and Enabling Service: $myservice"
	systemctl start $myservice
	systemctl enable $myservice
	systemctl status $myservice
done


#
# Finally, we proceed to verify if HEAT was properlly installed. If not, we stop further procedings.
#

testheat=`rpm -qi openstack-heat-common|grep -ci "is not installed"`
if [ $testheat == "1" ]
then
	echo ""
	echo "HEAT Installation FAILED. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/heat-installed
	date > /etc/openstack-control-script-config/heat
fi


echo ""
echo "Heat Installed and Configured"
echo ""

