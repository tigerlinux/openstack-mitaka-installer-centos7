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

if [ -f /etc/openstack-control-script-config/designate-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We install designate related packages and dependencies
#

#
# First, we proceed to install and configure BIND for designate
#

yum -y install bind

systemctl enable named
systemctl restart named
sleep 5
sync

cat ./libs/designate/named.conf > /etc/named.conf
chown named.named /var/named

sync
systemctl restart named


echo ""
echo "Installing Designate Packages"

yum -y install openstack-designate-agent \
	openstack-designate-api \
	openstack-designate-central \
	openstack-designate-common \
	openstack-designate-mdns \
	openstack-designate-pool-manager \
	openstack-designate-sink \
	openstack-designate-zone-manager \
	python-designateclient

echo "Done"
echo ""

source $keystone_admin_rc_file

#
# By using python based "ini" config tools, we proceed to configure Designate
#

echo ""
echo "Configuring Designate"
echo ""

#
# Common config options
# 

crudini --set /etc/designate/designate.conf DEFAULT verbose False
crudini --set /etc/designate/designate.conf DEFAULT debug False
crudini --set /etc/designate/designate.conf DEFAULT logdir /var/log/designate
crudini --set /etc/designate/designate.conf DEFAULT log_dir /var/log/designate
crudini --set /etc/designate/designate.conf DEFAULT notification_driver messagingv2
crudini --set /etc/designate/designate.conf DEFAULT notification_topics notifications
crudini --set /etc/designate/designate.conf oslo_messaging_notifications driver messagingv2
crudini --set /etc/designate/designate.conf DEFAULT root_helper "sudo designate-rootwrap /etc/designate/rootwrap.conf"
crudini --set /etc/designate/designate.conf DEFAULT state_path "/var/lib/designate"
crudini --set /etc/designate/designate.conf DEFAULT network_api neutron
crudini --set /etc/designate/designate.conf DEFAULT supported_record_type "A, AAAA, CNAME, MX, SRV, TXT, SPF, NS, PTR, SSHFP, SOA"

#
# API Service
#

crudini --set /etc/designate/designate.conf "service:api" api_host 0.0.0.0
crudini --set /etc/designate/designate.conf "service:api" api_port 9001
crudini --set /etc/designate/designate.conf "service:api" auth_strategy keystone
crudini --set /etc/designate/designate.conf "service:api" enable_api_v1 True
crudini --set /etc/designate/designate.conf "service:api" enable_api_v2 True
crudini --set /etc/designate/designate.conf "service:api" enabled_extensions_v1 "diagnostics, quotas, reports, sync, touch"
crudini --set /etc/designate/designate.conf "service:api" enabled_extensions_v2 "diagnostics, quotas, reports, sync, touch"

#
# Keystone Authentication
#

crudini --set /etc/designate/designate.conf keystone_authtoken auth_host $keystonehost
crudini --set /etc/designate/designate.conf keystone_authtoken auth_port 35357
crudini --set /etc/designate/designate.conf keystone_authtoken auth_protocol http
crudini --set /etc/designate/designate.conf keystone_authtoken admin_tenant_name $keystoneservicestenant
crudini --set /etc/designate/designate.conf keystone_authtoken admin_user $designateuser
crudini --set /etc/designate/designate.conf keystone_authtoken admin_password $designatepass
crudini --set /etc/designate/designate.conf keystone_authtoken auth_uri http://$keystonehost:5000
crudini --set /etc/designate/designate.conf keystone_authtoken auth_url http://$keystonehost:35357
crudini --set /etc/designate/designate.conf keystone_authtoken auth_type password
crudini --set /etc/designate/designate.conf keystone_authtoken memcached_servers $keystonehost:11211
crudini --set /etc/designate/designate.conf keystone_authtoken project_domain_name $keystonedomain
crudini --set /etc/designate/designate.conf keystone_authtoken user_domain_name $keystonedomain
crudini --set /etc/designate/designate.conf keystone_authtoken project_name $keystoneservicestenant
crudini --set /etc/designate/designate.conf keystone_authtoken username $designateuser
crudini --set /etc/designate/designate.conf keystone_authtoken password $designatepass

#
# Designate Default Pool - NOTE: This is probably not needed anymore as pool's are configured
# directly in the database by using a "yaml" file as source
#

crudini --set /etc/designate/designate.conf "service:pool_manager" pool_id "794ccc2c-d751-44fe-b57f-8894c9f5c842"
crudini --set /etc/designate/designate.conf "service:pool_manager" cache_driver sqlalchemy

crudini --set /etc/designate/designate.conf "pool:794ccc2c-d751-44fe-b57f-8894c9f5c842" nameservers "0f66b842-96c2-4189-93fc-1dc95a08b012"
crudini --set /etc/designate/designate.conf "pool:794ccc2c-d751-44fe-b57f-8894c9f5c842" targets "f26e0b32-736f-4f0a-831b-039a415c481e"

crudini --set /etc/designate/designate.conf "pool_nameserver:0f66b842-96c2-4189-93fc-1dc95a08b012" port 53
crudini --set /etc/designate/designate.conf "pool_nameserver:0f66b842-96c2-4189-93fc-1dc95a08b012" host $designatehost

crudini --set /etc/designate/designate.conf "pool_target:f26e0b32-736f-4f0a-831b-039a415c481e" options "rndc_host: 127.0.0.1, rndc_port: 953, rndc_key_file: /etc/rndc.key, port: 53, host: 127.0.0.1, clean_zonefile: False"
crudini --set /etc/designate/designate.conf "pool_target:f26e0b32-736f-4f0a-831b-039a415c481e" masters "127.0.0.1:5354"
crudini --set /etc/designate/designate.conf "pool_target:f26e0b32-736f-4f0a-831b-039a415c481e" type bind9

#
# Central Service
#

crudini --set /etc/designate/designate.conf "service:central" default_pool_id "794ccc2c-d751-44fe-b57f-8894c9f5c842"
# Note: The trailing dot is not a mistake... is on purpose. All domains in designate MUST finish with a dot
crudini --set /etc/designate/designate.conf "service:central" managed_resource_email $zonepooldefaultemail.
crudini --set /etc/designate/designate.conf "service:central" max_domain_name_len 255
crudini --set /etc/designate/designate.conf "service:central" max_recordset_name_len 255
crudini --set /etc/designate/designate.conf "service:central" scheduler_filters default_pool
crudini --set /etc/designate/designate.conf "service:central" backend_driver bind9

#
# Databases
#

case $dbflavor in
"mysql")
	crudini --set /etc/designate/designate.conf "storage:sqlalchemy" connection mysql+pymysql://$designatedbuser:$designatedbpass@$dbbackendhost:$mysqldbport/$designatedbname
	crudini --set /etc/designate/designate.conf "pool_manager_cache:sqlalchemy" connection mysql+pymysql://$designatedbuser:$designatedbpass@$dbbackendhost:$mysqldbport/$designatedbpoolmanagerdb
	;;
"postgres")
	crudini --set /etc/designate/designate.conf "storage:sqlalchemy" connection postgresql://$designatedbuser:$designatedbpass@$dbbackendhost:$psqldbport/$designatedbname
	crudini --set /etc/designate/designate.conf "pool_manager_cache:sqlalchemy" connection postgresql://$designatedbuser:$designatedbpass@$dbbackendhost:$psqldbport/$designatedbpoolmanagerdb
	;;
esac

#
# RPC Services
#

crudini --set /etc/designate/designate.conf DEFAULT rpc_backend rabbit
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_host $messagebrokerhost
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_password $brokerpass
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_userid $brokeruser
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_port 5672
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_use_ssl false
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_virtual_host $brokervhost
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_max_retries 0
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_retry_interval 1
crudini --set /etc/designate/designate.conf oslo_messaging_rabbit rabbit_ha_queues false

#
# Designate Agent (we are not using it now, but just to be prepared for the future...
#

crudini --set /etc/designate/designate.conf "backend:agent:bind9" rndc_host 127.0.0.1
crudini --set /etc/designate/designate.conf "backend:agent:bind9" rndc_port 953
crudini --set /etc/designate/designate.conf "backend:agent:bind9" rndc_key_file "/etc/rndc.key"
crudini --set /etc/designate/designate.conf "backend:agent:bind9" zone_file_path "/var/lib/designate/zones"
crudini --set /etc/designate/designate.conf "backend:agent:bind9" query_destination 127.0.0.1

#
# mdns service
#

crudini --set /etc/designate/designate.conf "service:mdns" host 0.0.0.0
crudini --set /etc/designate/designate.conf "service:mdns" port 5354
crudini --set /etc/designate/designate.conf "service:mdns" query_enforce_tsig False
crudini --set /etc/designate/designate.conf "service:mdns" tcp_backlog 100
crudini --set /etc/designate/designate.conf "service:mdns" tcp_recv_timeout 0.5
crudini --set /etc/designate/designate.conf "service:mdns" all_tcp False
crudini --set /etc/designate/designate.conf "service:mdns" max_message_size 65535

mkdir /var/lib/designate/zones
chown designate.designate /var/lib/designate/zones

echo ""
echo "Designate Configured"
echo ""

#
# With the configuration done, we proceed to provision/update Designate database
#

echo ""
echo "Provisioning Designate DB and Pool Cache Database"
echo ""

su -s /bin/sh -c "designate-manage database sync" designate
su -s /bin/sh -c "designate-manage pool-manager-cache sync" designate

#
# Then we apply IPTABLES rules
#

echo ""
echo "Applying IPTABLES rules"

iptables -A INPUT -p tcp -m multiport --dports 9001,5354,53 -j ACCEPT
iptables -A INPUT -p udp -m multiport --dports 5354,53 -j ACCEPT
service iptables save

#
# And proceed to provision our default pool and TLD's
#

echo ""
echo "Provisioning default pool and TLD's list"
echo ""

cat ./libs/designate/pools.yaml > /etc/designate/pools.yaml

mydnshostname=`hostname`

sed -s -i "s/DESIGNATEHOSTNAME/$mydnshostname/g" /etc/designate/pools.yaml

systemctl start designate-api
systemctl start designate-central
systemctl enable designate-api
systemctl enable designate-central

sleep 5
sync
sleep 5

designate-manage pool update --file /etc/designate/pools.yaml

cat ./libs/designate/tlds-alpha-by-domain.txt > /etc/designate/tlds-alpha-by-domain.txt

designate-manage tlds import --input_file /etc/designate/tlds-alpha-by-domain.txt

rm -f $dnsextratldfile
touch $dnsextratldfile

for tld in $dnsextratlds
do
	echo $tld >>  $dnsextratldfile
done

designate-manage tlds import --input_file $dnsextratldfile

#
# We start/enable remaining services
#

systemctl start designate-mdns
systemctl start designate-pool-manager
systemctl start designate-zone-manager
systemctl enable designate-mdns
systemctl enable designate-pool-manager
systemctl enable designate-zone-manager

echo ""
echo "Done"
echo ""

#
# Now, if choosen by the "carbon unit" using this tool, we proceed to configure the SINK service
#

if [ $dnssinkactivate == "yes" ]
then
	#
	# First, we need to create the zone. Again, the trailing dot is there on purpose:
	source $keystone_fulladmin_rc_file
	openstack zone create --email $dnssinkdomainemail --type PRIMARY $dnssinkdomain.
	myzoneid=`openstack zone show $dnssinkdomain. -f shell|grep ^id=\"|cut -d\" -f2`
	crudini --set /etc/designate/designate.conf "service:sink" enabled_notification_handlers "nova_fixed, neutron_floatingip" 
	crudini --set /etc/designate/designate.conf "network_api:neutron" endpoints "$endpointsregion|http://$neutronhost:9696"
	crudini --set /etc/designate/designate.conf "network_api:neutron" endpoint_type publicURL
	crudini --set /etc/designate/designate.conf "network_api:neutron" admin_username $designateuser
	crudini --set /etc/designate/designate.conf "network_api:neutron" admin_password $designatepass
	crudini --set /etc/designate/designate.conf "network_api:neutron" admin_tenant_name $keystoneservicestenant
	crudini --set /etc/designate/designate.conf "network_api:neutron" auth_url "http://$keystonehost:35357"
	crudini --set /etc/designate/designate.conf "network_api:neutron" auth_strategy keystone
	crudini --set /etc/designate/designate.conf "handler:nova_fixed" domain_id \"$myzoneid\"
	crudini --set /etc/designate/designate.conf "handler:nova_fixed" zone_id \"$myzoneid\"
	crudini --set /etc/designate/designate.conf "handler:nova_fixed" notification_topics notifications
	crudini --set /etc/designate/designate.conf "handler:nova_fixed" control_exchange "'nova'"
	crudini --set /etc/designate/designate.conf "handler:nova_fixed" format "'instance-%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.instancenames.%(zone)s'"
	crudini --set /etc/designate/designate.conf "handler:neutron_floatingip" domain_id \"$myzoneid\"
	crudini --set /etc/designate/designate.conf "handler:neutron_floatingip" zone_id \"$myzoneid\"
	crudini --set /etc/designate/designate.conf "handler:neutron_floatingip" notification_topics notifications
	crudini --set /etc/designate/designate.conf "handler:neutron_floatingip" control_exchange "'neutron'"
	crudini --set /etc/designate/designate.conf "handler:neutron_floatingip" format "'instance-%(octet0)s-%(octet1)s-%(octet2)s-%(octet3)s.fips.%(zone)s'"
	#
	# With the sink configured, we need to activate the service:
	systemctl start designate-sink
	systemctl enable designate-sink
fi

#
# Finally, we perform a package installation check. If we fail this, we stop the main installer
# from this point.
#

testdesignate=`rpm -qi openstack-designate-common|grep -ci "is not installed"`
if [ $testdesignate == "1" ]
then
	echo ""
	echo "Designate Installation Failed. Aborting !"
	echo ""
	exit 0
else
	date > /etc/openstack-control-script-config/designate-installed
	date > /etc/openstack-control-script-config/designate
	if [ $dnssinkactivate == "yes" ]
	then
		date > /etc/openstack-control-script-config/designate-sink-installed
		date > /etc/openstack-control-script-config/designate-sink
	fi
fi


echo ""
echo "Designate Installed and Configured"
echo ""



