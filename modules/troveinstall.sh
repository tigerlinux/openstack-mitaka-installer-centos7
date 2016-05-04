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
	echo "Keystone Proccess not completed. Aborting !."
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/trove-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We proceed to install all trove packages and dependencies
#

echo ""
echo "Installing Trove Packages"

yum install -y openstack-trove-api \
	openstack-trove \
	openstack-trove-common \
	openstack-trove-taskmanager \
	openstack-trove-conductor \
	python-troveclient \
	python-trove \
	openstack-utils \
	openstack-selinux

echo "Ready"
echo ""

source $keystone_admin_rc_file

#
# By using a python based "ini" config tool, we proceed to configure trove services
#

echo ""
echo "Configuring Trove"
echo ""


cat ./libs/trove/api-paste.ini > /etc/trove/api-paste.ini
cat ./libs/trove/trove.conf > /etc/trove/trove.conf
cat ./libs/trove/trove-taskmanager.conf > /etc/trove/trove-taskmanager.conf
cat ./libs/trove/trove-conductor.conf > /etc/trove/trove-conductor.conf
cat ./libs/trove/trove-guestagent.conf > /etc/trove/trove-guestagent.conf

chown trove.trove /etc/trove/*

commonfile='
	/etc/trove/trove.conf
	/etc/trove/trove-taskmanager.conf
	/etc/trove/trove-conductor.conf
'

for myconffile in $commonfile
do
	echo "Configuring file $myconffile"
	sleep 3
	echo "#" >> $myconffile

	case $dbflavor in
	"mysql")
		crudini --set $myconffile database connection mysql+pymysql://$trovedbuser:$trovedbpass@$dbbackendhost:$mysqldbport/$trovedbname
		crudini --set $myconffile database idle_timeout 3600
		;;
	"postgres")
		# crudini --set $myconffile database connection postgresql+psycopg2://$trovedbuser:$trovedbpass@$dbbackendhost:$psqldbport/$trovedbname
		crudini --set $myconffile database connection postgresql://$trovedbuser:$trovedbpass@$dbbackendhost:$psqldbport/$trovedbname
		crudini --set $myconffile database idle_timeout 3600
		;;
	esac

	crudini --set $myconffile DEFAULT log_dir /var/log/trove
	crudini --set $myconffile DEFAULT verbose False
	crudini --set $myconffile DEFAULT debug False
	crudini --set $myconffile DEFAULT control_exchange trove
	# crudini --set $myconffile DEFAULT trove_auth_url http://$keystonehost:5000/v2.0
	crudini --set $myconffile DEFAULT trove_auth_url http://$keystonehost:5000/v3
	crudini --set $myconffile DEFAULT nova_compute_url http://$novahost:8774/v2.1
	crudini --set $myconffile DEFAULT cinder_url http://$cinderhost:8776/v2
	crudini --set $myconffile DEFAULT swift_url http://$swifthost:8080/v1/AUTH_
	crudini --set $myconffile DEFAULT notifier_queue_hostname $messagebrokerhost
 
	case $brokerflavor in
	"qpid")
		crudini --set $myconffile DEFAULT rpc_backend trove.openstack.common.rpc.impl_qpid
		crudini --del $myconffile DEFAULT rabbit_password
		crudini --set $myconffile oslo_messaging_qpid qpid_hostname $messagebrokerhost
		crudini --set $myconffile oslo_messaging_qpid qpid_port 5672
		crudini --set $myconffile oslo_messaging_qpid qpid_username $brokeruser
		crudini --set $myconffile oslo_messaging_qpid qpid_password $brokerpass
		crudini --set $myconffile oslo_messaging_qpid qpid_heartbeat 60
		crudini --set $myconffile oslo_messaging_qpid qpid_protocol tcp
		crudini --set $myconffile oslo_messaging_qpid qpid_tcp_nodelay True
		;;
	"rabbitmq")
		crudini --set $myconffile DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
		crudini --set $myconffile DEFAULT rabbit_password $brokerpass
		crudini --set $myconffile oslo_messaging_rabbit rabbit_host $messagebrokerhost
		crudini --set $myconffile oslo_messaging_rabbit rabbit_password $brokerpass
		crudini --set $myconffile oslo_messaging_rabbit rabbit_userid $brokeruser
		crudini --set $myconffile oslo_messaging_rabbit rabbit_port 5672
		crudini --set $myconffile oslo_messaging_rabbit rabbit_use_ssl false
		crudini --set $myconffile oslo_messaging_rabbit rabbit_virtual_host $brokervhost
		crudini --set $myconffile oslo_messaging_rabbit rabbit_max_retries 0
		crudini --set $myconffile oslo_messaging_rabbit rabbit_retry_interval 1
		crudini --set $myconffile oslo_messaging_rabbit rabbit_ha_queues false
		;;
	esac
done

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user $keystoneadminuser
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $keystoneadminpass
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant

crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_user $keystoneadminuser
crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_pass $keystoneadminpass
crudini --set /etc/trove/trove.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant

crudini --set /etc/trove/trove.conf DEFAULT taskmanager_queue taskmanager
crudini --set /etc/trove/trove.conf DEFAULT admin_roles $keystoneadminuser
crudini --set /etc/trove/trove.conf DEFAULT os_region_name $endpointsregion

crudini --set /etc/trove/trove.conf DEFAULT nova_compute_service_type compute
crudini --set /etc/trove/trove.conf DEFAULT cinder_service_type volumev2
crudini --set /etc/trove/trove.conf DEFAULT swift_service_type object-store
crudini --set /etc/trove/trove.conf DEFAULT heat_service_type orchestration
crudini --set /etc/trove/trove.conf DEFAULT neutron_service_type network

# Failsafe #1
crudini --del /etc/trove/trove.conf DEFAULT nova_compute_url
crudini --del /etc/trove/trove.conf DEFAULT cinder_url
crudini --del /etc/trove/trove.conf DEFAULT swift_url
crudini --del /etc/trove/trove.conf DEFAULT trove_auth_url
# Failsafe #2
crudini --del /etc/trove/trove.conf DEFAULT nova_compute_url
crudini --del /etc/trove/trove.conf DEFAULT cinder_url
crudini --del /etc/trove/trove.conf DEFAULT swift_url
crudini --del /etc/trove/trove.conf DEFAULT trove_auth_url

# crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_user $keystoneadminuser
# crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_pass $keystoneadminpass
# crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_user $novauser
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_pass $novapass
crudini --set /etc/trove/trove-conductor.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant

# Failsafe #1
crudini --del /etc/trove/trove-conductor.conf DEFAULT nova_compute_url
crudini --del /etc/trove/trove-conductor.conf DEFAULT cinder_url
crudini --del /etc/trove/trove-conductor.conf DEFAULT swift_url

# Failsafe #2
crudini --del /etc/trove/trove-conductor.conf DEFAULT nova_compute_url
crudini --del /etc/trove/trove-conductor.conf DEFAULT cinder_url
crudini --del /etc/trove/trove-conductor.conf DEFAULT swift_url

# crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user $keystoneadminuser
# crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $keystoneadminpass
# crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_user $novauser
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_pass $novapass
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT taskmanager_queue taskmanager

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT notification_driver messagingv2

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT guest_config "/etc/trove/trove-guestagent.conf"
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT guest_info "/etc/trove/guest_info"
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT injected_config_location "/etc/trove/"
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT cloudinit_location "/etc/trove/cloudinit"

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT os_region_name $endpointsregion

crudini --set /etc/trove/trove-taskmanager.conf DEFAULT nova_compute_service_type compute
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT cinder_service_type volumev2
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT swift_service_type object-store
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT heat_service_type orchestration
crudini --set /etc/trove/trove-taskmanager.conf DEFAULT neutron_service_type network

if [ $trovevolsupport == "yes" ]
then
	crudini --set /etc/trove/trove.conf DEFAULT trove_volume_support True
	crudini --set /etc/trove/trove.conf DEFAULT block_device_mapping $trovevoldevice
	crudini --set /etc/trove/trove.conf DEFAULT device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mysql volume_support True
	crudini --set /etc/trove/trove.conf mysql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mariadb volume_support True
	crudini --set /etc/trove/trove.conf mariadb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf postgresql volume_support True
	crudini --set /etc/trove/trove.conf postgresql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf cassandra volume_support True
	crudini --set /etc/trove/trove.conf cassandra device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf couchbase volume_support True
	crudini --set /etc/trove/trove.conf couchbase device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mongodb volume_support True
	crudini --set /etc/trove/trove.conf mongodb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf vertica volume_support True
	crudini --set /etc/trove/trove.conf vertica device_path "/dev/$trovevoldevice"
else
	crudini --set /etc/trove/trove.conf DEFAULT trove_volume_support False
	crudini --set /etc/trove/trove.conf DEFAULT block_device_mapping $trovevoldevice
	crudini --set /etc/trove/trove.conf DEFAULT device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mysql volume_support False
	crudini --set /etc/trove/trove.conf mysql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mariadb volume_support False
	crudini --set /etc/trove/trove.conf mariadb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf postgresql volume_support False
	crudini --set /etc/trove/trove.conf postgresql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf cassandra volume_support False
	crudini --set /etc/trove/trove.conf cassandra device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf couchbase volume_support False
	crudini --set /etc/trove/trove.conf couchbase device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf mongodb volume_support False
	crudini --set /etc/trove/trove.conf mongodb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove.conf vertica volume_support False
	crudini --set /etc/trove/trove.conf vertica device_path "/dev/$trovevoldevice"
fi

if [ $trovevolsupport == "yes" ]
then
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT trove_volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT block_device_mapping $trovevoldevice
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mysql volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf mysql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mariadb volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf mariadb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf postgresql volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf postgresql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf cassandra volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf cassandra device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf couchbase volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf couchbase device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mongodb volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf mongodb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf vertica volume_support True
	crudini --set /etc/trove/trove-taskmanager.conf vertica device_path "/dev/$trovevoldevice"
else
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT trove_volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT block_device_mapping $trovevoldevice
	crudini --set /etc/trove/trove-taskmanager.conf DEFAULT device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mysql volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf mysql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mariadb volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf mariadb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf postgresql volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf postgresql device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf cassandra volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf cassandra device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf couchbase volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf couchbase device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf mongodb volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf mongodb device_path "/dev/$trovevoldevice"
	crudini --set /etc/trove/trove-taskmanager.conf vertica volume_support False
	crudini --set /etc/trove/trove-taskmanager.conf vertica device_path "/dev/$trovevoldevice"
fi

crudini --set /etc/trove/trove.conf DEFAULT notification_driver messagingv2

crudini --set /etc/trove/trove.conf DEFAULT default_datastore $trovedefaultds
 
crudini --set /etc/trove/trove.conf DEFAULT add_addresses True
crudini --set /etc/trove/trove.conf DEFAULT network_label_regex "^NETWORK_LABEL$"
crudini --set /etc/trove/trove.conf DEFAULT api_paste_config /etc/trove/api-paste.ini
crudini --set /etc/trove/trove.conf DEFAULT bind_host 0.0.0.0
crudini --set /etc/trove/trove.conf DEFAULT bind_port 8779
crudini --set /etc/trove/trove.conf DEFAULT taskmanager_manager trove.taskmanager.manager.Manager
 
troveworkers=`grep processor.\*: /proc/cpuinfo |wc -l`
 
crudini --set /etc/trove/trove.conf DEFAULT trove_api_workers $troveworkers
 
crudini --set /etc/trove/trove.conf keystone_authtoken signing_dir /var/cache/trove
crudini --set /etc/trove/trove.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/trove/trove.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/trove/trove.conf keystone_authtoken auth_plugin password
crudini --set /etc/trove/trove.conf keystone_authtoken auth_type password
crudini --set /etc/trove/trove.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/trove/trove.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/trove/trove.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/trove/trove.conf keystone_authtoken username $troveuser
crudini --set /etc/trove/trove.conf keystone_authtoken password $trovepass
crudini --set /etc/trove/trove.conf keystone_authtoken auth_host $keystonehost
crudini --set /etc/trove/trove.conf keystone_authtoken auth_port 35357
crudini --set /etc/trove/trove.conf keystone_authtoken auth_protocol http
crudini --set /etc/trove/trove.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/trove/trove.conf keystone_authtoken admin_user $troveuser
crudini --set /etc/trove/trove.conf keystone_authtoken admin_password $trovepass
crudini --set /etc/trove/trove.conf keystone_authtoken auth_version v3
crudini --set /etc/trove/trove.conf keystone_authtoken region $endpointsregion
crudini --set /etc/trove/trove.conf keystone_authtoken memcached_servers $keystonehost:11211

crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken signing_dir /var/cache/trove
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_plugin password
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_type password
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken username $troveuser
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken password $trovepass
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_host $keystonehost
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_port 35357
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_protocol http
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_user $troveuser
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken admin_password $trovepass
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken auth_version v3
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken region $endpointsregion
crudini --set /etc/trove/trove-taskmanager.conf keystone_authtoken memcached_servers $keystonehost:11211


mkdir -p /var/cache/trove
mkdir -p /etc/trove/cloudinit
mkdir -p /etc/trove/templates
chown -R trove.trove /var/cache/trove
chown -R trove.trove /etc/trove/*
chmod 700 /var/cache/trove
chmod 700 /var/log/trove

touch /var/log/trove/trove-manage.log
chown trove.trove /var/log/trove/*

echo ""
echo "Trove Configured"
echo ""

#
# We provision/update Trove database
#

echo ""
echo "Provisioning Trove DB"
echo ""

su -s /bin/sh -c "trove-manage db_sync" trove

#
# And we create the default datastore
#

echo ""
echo "Creating Trove $trovedefaultds Datastore"
echo ""

su -s /bin/sh -c "trove-manage datastore_update $trovedefaultds ''" trove

echo ""
echo "Done"
echo ""

#
# Here we apply IPTABLES rules and start/enable trove services
#

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 8779 -j ACCEPT
service iptables save

echo "Done"

echo ""
echo "Cleaning UP App logs"
 
for mylog in `ls /var/log/trove/*.log`; do echo "" > $mylog;done
 
echo "Done"
echo ""

echo ""
echo "Starting Services"
echo ""

servicelist='
	openstack-trove-api
	openstack-trove-taskmanager
	openstack-trove-conductor
'

for myservice in $servicelist
do
	echo "Starting and Enabling Service: $myservice"
	systemctl start $myservice
	systemctl enable $myservice
	systemctl status $myservice
done

# service openstack-trove-api start
# service openstack-trove-taskmanager start
# service openstack-trove-conductor start
# chkconfig openstack-trove-api on
# chkconfig openstack-trove-taskmanager on
# chkconfig openstack-trove-conductor on

#
# And finally, we do a little test to ensure our trove packages are installed. If we
# fail this test, we stop the installer from this point.
#

testtrove=`rpm -qi openstack-trove-common|grep -ci "is not installed"`
if [ $testtrove == "1" ]
then
	echo ""
	echo "Trove Installation Failed. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/trove-installed
	date > /etc/openstack-control-script-config/trove
fi

echo ""
echo "Creating sample trove-guestagent file: /etc/trove/trove-guestagent.conf"
echo ""

crudini --set /etc/trove/trove-guestagent.conf DEFAULT verbose False
crudini --set /etc/trove/trove-guestagent.conf DEFAULT debug False
# crudini --set /etc/trove/trove-guestagent.conf DEFAULT datastore_manager $trovedefaultds
crudini --set /etc/trove/trove-guestagent.conf DEFAULT control_exchange trove
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_user $novauser
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_pass $novapass
crudini --set /etc/trove/trove-guestagent.conf DEFAULT nova_proxy_admin_tenant_name $keystoneadmintenant
# crudini --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url http://$keystonehost:35357/v2.0
crudini --set /etc/trove/trove-guestagent.conf DEFAULT trove_auth_url http://$keystonehost:35357/v3
crudini --set /etc/trove/trove-guestagent.conf DEFAULT log_dir "/var/log/trove/"
crudini --set /etc/trove/trove-guestagent.conf DEFAULT log_file guestagent.log

crudini --set /etc/trove/trove-guestagent.conf DEFAULT os_region_name $endpointsregion
crudini --set /etc/trove/trove-guestagent.conf DEFAULT swift_service_type object-store
crudini --set /etc/trove/trove-guestagent.conf DEFAULT storage_strategy SwiftStorage
crudini --set /etc/trove/trove-guestagent.conf DEFAULT storage_namespace trove.guestagent.strategies.storage.swift
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_swift_container database_backups
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_use_gzip_compression True
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_use_openssl_encryption True
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_aes_cbc_key \"default_aes_cbc_key\"
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_use_snet False
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_chunk_size 65536
crudini --set /etc/trove/trove-guestagent.conf DEFAULT backup_segment_max_size 2147483648


case $brokerflavor in
"qpid")
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_qpid
	crudini --del /etc/trove/trove-guestagent.conf DEFAULT rabbit_password
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_hostname $messagebrokerhost
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_port 5672
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_username $brokeruser
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_password $brokerpass
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_heartbeat 60
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_protocol tcp
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT qpid_tcp_nodelay True
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_hostname $messagebrokerhost
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_port 5672
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_username $brokeruser
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_password $brokerpass
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_heartbeat 60
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_protocol tcp
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_qpid qpid_tcp_nodelay True
	;;
"rabbitmq")
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rpc_backend trove.openstack.common.rpc.impl_kombu
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_password $brokerpass
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_host $messagebrokerhost
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_userid $brokeruser
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_port 5672
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_use_ssl false
	crudini --set /etc/trove/trove-guestagent.conf DEFAULT rabbit_virtual_host $brokervhost
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_password $brokerpass
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_userid $brokeruser
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_port 5672
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_use_ssl false
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_max_retries 0
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_retry_interval 1
	crudini --set /etc/trove/trove-guestagent.conf oslo_messaging_rabbit rabbit_ha_queues false
	;;
esac

chown trove.trove /etc/trove/trove-guestagent.conf

echo ""
echo "Trove Installed and Configured"
echo ""

