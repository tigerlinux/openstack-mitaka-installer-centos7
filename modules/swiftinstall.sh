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

if [ -f /etc/openstack-control-script-config/swift-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

#
# We perform some validations related to the filesystem device and mount point. If those
# validations fail, we abort from here !.
#

echo ""
echo "Preparing FS Resources"
echo ""

if [ ! -d "/srv/node" ]
then
	rm -f /etc/openstack-control-script-config/swift
	echo ""
	echo "WARNING !. the main mount point is not here. Aborting swift installation"
	echo "OpenStack installation will continue, but without swift"
	echo "Sleeping 10 seconds"
	echo ""
	sleep 10
	exit 0
fi

checkdevice=`mount|awk '{print $3}'|grep -c ^/srv/node/$swiftdevice$`

case $checkdevice in
1)
	echo ""
	echo "Mount Point /srv/node/$swiftdevice OK"
	echo "Let's continue"
	echo ""
	;;
0)
	rm -f /etc/openstack-control-script-config/swift
	rm -f /etc/openstack-control-script-config/swift-installed
	echo ""
	echo "WARNING !. the main swift device is not here. Aborting swift installation"
	echo "OpenStack installation will continue, but without swift"
	echo "Sleeping 10 seconds"
	echo ""
	sleep 10
	echo ""
	exit 0
	;;
esac

if [ $cleanupdeviceatinstall == "yes" ]
then
	rm -rf /srv/node/$swiftdevice/accounts
	rm -rf /srv/node/$swiftdevice/containers
	rm -rf /srv/node/$swiftdevice/objects
	rm -rf /srv/node/$swiftdevice/tmp
fi

#
# Validations done OK, then we proceed to install packages
#

echo ""
echo "Installing Swift Packages"

yum install -y openstack-swift-proxy \
	openstack-swift-object \
	openstack-swift-container \
	openstack-swift-account \
	openstack-utils \
	openstack-swift-plugin-swift3 \
	openstack-swift \
	memcached

yum install -y xfsprogs rsync

echo "Done"
echo ""

source $keystone_admin_rc_file

#
# We apply IPTABLES rules
#

iptables -A INPUT -p tcp -m multiport --dports 6000,6001,6002,873 -j ACCEPT
service iptables save

#
# We need to fix permissions and selinux
#

chown -R swift:swift /srv/node/
restorecon -R /srv

#
# By using a python based "ini" config tool, we proceed to configure swift services
#

echo ""
echo "Configuring Swift"
echo ""


# First, as we obtained the configurations from the main git repository, we ensure
# all of those configs are properlly copied to the swift directory
#

cat ./libs/swift/account-server.conf > /etc/swift/account-server.conf
cat ./libs/swift/container-reconciler.conf > /etc/swift/container-reconciler.conf
cat ./libs/swift/container-server.conf > /etc/swift/container-server.conf
cat ./libs/swift/object-expirer.conf > /etc/swift/object-expirer.conf
cat ./libs/swift/object-server.conf > /etc/swift/object-server.conf
cat ./libs/swift/proxy-server.conf > /etc/swift/proxy-server.conf
cat ./libs/swift/swift.conf > /etc/swift/swift.conf

# RSYNC Too
cat ./libs/swift/rsyncd.conf > /etc/rsyncd.conf
sed -r -i "s/MANAGEMENT_INTERFACE_IP_ADDRESS/$swifthost/g" /etc/rsyncd.conf

systemctl enable rsyncd.service
systemctl start rsyncd.service

echo "#" >> /etc/swift/swift.conf

chown -R swift:swift /etc/swift

mkdir -p /var/lib/keystone-signing-swift
chown swift:swift /var/lib/keystone-signing-swift

crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_suffix $(openssl rand -hex 10)
crudini --set /etc/swift/swift.conf swift-hash swift_hash_path_prefix $(openssl rand -hex 10)
crudini --set /etc/swift/swift.conf "storage-policy:0" name Policy-0
crudini --set /etc/swift/swift.conf "storage-policy:0" default yes
 
#swiftworkers=`grep processor.\*: /proc/cpuinfo |wc -l`
swiftworkers="auto"

mkdir -p "/var/cache/swift"
chmod 0700 /var/cache/swift
chown -R swift:swift /var/cache/swift
# chown -R root:swift /var/cache/swift
 
crudini --set /etc/swift/object-server.conf DEFAULT bind_ip $swifthost
crudini --set /etc/swift/object-server.conf DEFAULT workers $swiftworkers
crudini --set /etc/swift/object-server.conf DEFAULT swift_dir "/etc/swift"
crudini --set /etc/swift/object-server.conf DEFAULT devices "/srv/node"
crudini --set /etc/swift/object-server.conf DEFAULT bind_port 6000
crudini --set /etc/swift/object-server.conf DEFAULT mount_check true
crudini --set /etc/swift/object-server.conf DEFAULT user swift
crudini --set /etc/swift/object-server.conf "pipeline:main" pipeline "healthcheck recon object-server"
crudini --set /etc/swift/object-server.conf "filter:recon" use "egg:swift#recon"
crudini --set /etc/swift/object-server.conf "filter:recon" recon_cache_path "/var/cache/swift"
crudini --set /etc/swift/object-server.conf "filter:recon" recon_lock_path "/var/lock"

crudini --set /etc/swift/account-server.conf DEFAULT bind_ip $swifthost
crudini --set /etc/swift/account-server.conf DEFAULT workers $swiftworkers
crudini --set /etc/swift/account-server.conf DEFAULT swift_dir "/etc/swift"
crudini --set /etc/swift/account-server.conf DEFAULT devices "/srv/node"
crudini --set /etc/swift/account-server.conf DEFAULT bind_port 6002
crudini --set /etc/swift/account-server.conf DEFAULT mount_check true
crudini --set /etc/swift/account-server.conf DEFAULT user swift
crudini --set /etc/swift/account-server.conf "pipeline:main" pipeline "healthcheck recon account-server"
crudini --set /etc/swift/account-server.conf "filter:recon" use "egg:swift#recon"
crudini --set /etc/swift/account-server.conf "filter:recon" recon_cache_path "/var/cache/swift"

crudini --set /etc/swift/container-server.conf DEFAULT bind_ip $swifthost
crudini --set /etc/swift/container-server.conf DEFAULT workers $swiftworkers
crudini --set /etc/swift/container-server.conf DEFAULT swift_dir "/etc/swift"
crudini --set /etc/swift/container-server.conf DEFAULT devices "/srv/node"
crudini --set /etc/swift/container-server.conf DEFAULT bind_port 6001
crudini --set /etc/swift/container-server.conf DEFAULT mount_check true
crudini --set /etc/swift/container-server.conf DEFAULT user swift
crudini --set /etc/swift/container-server.conf "pipeline:main" pipeline "healthcheck recon container-server"
crudini --set /etc/swift/container-server.conf "filter:recon" "egg:swift#recon"
crudini --set /etc/swift/container-server.conf "filter:recon" recon_cache_path "/var/cache/swift"

#
# Then we proceed to configure the proxy service
#

crudini --set /etc/swift/proxy-server.conf DEFAULT bind_port 8080
crudini --set /etc/swift/proxy-server.conf DEFAULT user swift
crudini --set /etc/swift/proxy-server.conf DEFAULT swift_dir /etc/swift
crudini --set /etc/swift/proxy-server.conf DEFAULT workers $swiftworkers
crudini --set /etc/swift/proxy-server.conf "pipeline:main" pipeline "catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk ratelimit authtoken keystoneauth container-quotas account-quotas slo dlo versioned_writes proxy-logging proxy-server"
crudini --set /etc/swift/proxy-server.conf "app:proxy-server" use "egg:swift#proxy"
crudini --set /etc/swift/proxy-server.conf "app:proxy-server" allow_account_management true
crudini --set /etc/swift/proxy-server.conf "app:proxy-server" account_autocreate true
crudini --set /etc/swift/proxy-server.conf "filter:keystoneauth" use "egg:swift#keystoneauth"
crudini --set /etc/swift/proxy-server.conf "filter:keystoneauth" operator_roles "$keystoneadmintenant,$keystoneuserrole"
crudini --set /etc/swift/proxy-server.conf "filter:keystoneauth" reseller_admin_role $keystonereselleradminrole
crudini --set /etc/swift/proxy-server.conf "filter:keystoneauth" allow_overrides true

crudini --set /etc/swift/proxy-server.conf "filter:authtoken" paste.filter_factory "keystonemiddleware.auth_token:filter_factory"

crudini --set /etc/swift/proxy-server.conf "filter:authtoken" signing_dir /var/cache/swift
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" cache swift.cache
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" username $swiftuser
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" password $swiftpass
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" auth_type password
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" memcached_servers $keystonehost:11211
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" project_domain_name $keystonedomain
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" user_domain_name $keystonedomain
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" project_name $keystoneservicestenant
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" auth_uri http://$keystonehost:5000
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" auth_url http://$keystonehost:35357
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" include_service_catalog False
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" auth_version v3
crudini --set /etc/swift/proxy-server.conf "filter:authtoken" delay_auth_decision True

crudini --set /etc/swift/proxy-server.conf "filter:cache" use "egg:swift#memcache"
crudini --set /etc/swift/proxy-server.conf "filter:cache" memcache_servers $keystonehost:11211
crudini --set /etc/swift/proxy-server.conf "filter:catch_errors" use "egg:swift#catch_errors"
crudini --set /etc/swift/proxy-server.conf "filter:healthcheck" use "egg:swift#healthcheck"
crudini --set /etc/swift/proxy-server.conf "filter:proxy-logging" use "egg:swift#proxy_logging"
crudini --set /etc/swift/proxy-server.conf "filter:gatekeeper" use "egg:swift#gatekeeper"

ldconfig -v

#
# We start and enable some of the services before continuing the configuration
#

systemctl enable \
	openstack-swift-account.service \
	openstack-swift-account-auditor.service \
	openstack-swift-account-reaper.service \
	openstack-swift-account-replicator.service

systemctl start \
	openstack-swift-account.service \
	openstack-swift-account-auditor.service \
	openstack-swift-account-reaper.service \
	openstack-swift-account-replicator.service

systemctl enable \
	openstack-swift-container.service \
	openstack-swift-container-auditor.service \
	openstack-swift-container-replicator.service \
	openstack-swift-container-updater.service

systemctl start \
	openstack-swift-container.service \
	openstack-swift-container-auditor.service \
	openstack-swift-container-replicator.service \
	openstack-swift-container-updater.service

systemctl enable \
	openstack-swift-object.service \
	openstack-swift-object-auditor.service \
	openstack-swift-object-replicator.service \
	openstack-swift-object-updater.service

systemctl start \
	openstack-swift-object.service \
	openstack-swift-object-auditor.service \
	openstack-swift-object-replicator.service \
	openstack-swift-object-updater.service



#
# We start and enable swift proxy and memcached services
#

systemctl start memcached
systemctl start openstack-swift-proxy
systemctl enable memcached
systemctl enable openstack-swift-proxy

#
# Then perform more post configuration
#

echo ""
echo "Creating Initial Rings:2"
echo ""

swift-ring-builder /etc/swift/object.builder create $partition_power $replica_count $partition_min_hours
swift-ring-builder /etc/swift/container.builder create $partition_power $replica_count $partition_min_hours
swift-ring-builder /etc/swift/account.builder create $partition_power $replica_count $partition_min_hours

swift-ring-builder /etc/swift/account.builder add --region $swiftfirstregion --zone $swiftfirstzone --ip $swifthost --port 6002 --device $swiftdevice --weight 100
swift-ring-builder /etc/swift/container.builder add --region $swiftfirstregion --zone $swiftfirstzone --ip $swifthost --port 6001 --device $swiftdevice --weight 100
swift-ring-builder /etc/swift/object.builder add --region $swiftfirstregion --zone $swiftfirstzone --ip $swifthost --port 6000 --device $swiftdevice --weight 100

echo ""
echo "Rebalancing Rings:"
echo ""


swift-ring-builder /etc/swift/account.builder rebalance
swift-ring-builder /etc/swift/container.builder rebalance
swift-ring-builder /etc/swift/object.builder rebalance

echo ""
echo "Swift RING Report follows (waiting 10 seconds while you see the report):"
echo ""

swift-ring-builder /etc/swift/account.builder 
swift-ring-builder /etc/swift/container.builder 
swift-ring-builder /etc/swift/object.builder 

sleep 10

echo ""
echo "Continuing"
echo ""


chown -R swift:swift /etc/swift


sync
service openstack-swift-proxy stop
sleep 3
service openstack-swift-proxy start
sync

#
# More IPTABLES rules to apply
#

iptables -A INPUT -p tcp -m multiport --dports 8080,11211 -j ACCEPT
service iptables save

#
# We proceed to make a final full restart of all swift related services
#

swift_svc_start='
	openstack-swift-account
	openstack-swift-account-auditor
	openstack-swift-account-reaper
	openstack-swift-account-replicator
	openstack-swift-container
	openstack-swift-container-auditor
	openstack-swift-container-replicator
	openstack-swift-container-updater
	openstack-swift-object
	openstack-swift-object-auditor
	openstack-swift-object-replicator
	openstack-swift-object-updater
	openstack-swift-proxy
'
swift_svc_stop=`echo $swift_svc_start|tac -s' '`

echo ""
echo "Restarting Swift"
echo ""

for i in $swift_svc_stop
do
	service $i stop
done

killall -9 -u swift > /dev/null 2>&1

sync
sleep 5
sync

for i in $swift_svc_start
do
	service $i start
done

sync
sleep 5
sync

echo ""
echo "SWIFT Services:"
echo ""

for i in $swift_svc_start
do
	echo "Status service: $i"
        service $i status
	echo ""
done

#
# Finally, we perform a little check to ensure swift packages are here. If we fail this test,
# we stops the installer from here.
#

testswift=`rpm -qi openstack-swift-proxy|grep -ci "is not installed"`
if [ $testswift == "1" ]
then
	echo ""
	echo "Swift Installation Failed. Aborting !"
	echo ""
	rm -f /etc/openstack-control-script-config/swift
	rm -f /etc/openstack-control-script-config/swift-installed
	exit 0
else
	date > /etc/openstack-control-script-config/swift-installed
	date > /etc/openstack-control-script-config/swift
fi

echo ""
echo "Basic Swift Installation Finished"
echo ""

