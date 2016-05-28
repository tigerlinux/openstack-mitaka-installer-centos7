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
# First, we source our config file
#

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

clear

#
# We proceed to stops and disable all OpenStack services
#

echo "Stopping and deactivating OpenStack services"

/usr/local/bin/openstack-control.sh stop
/usr/local/bin/openstack-control.sh disable
service mongod stop
chkconfig mongod off

# Some Sanity clean up
killall -9 -u mongodb >/dev/null 2>&1
killall -9 mongod >/dev/null 2>&1
killall -9 dnsmasq >/dev/null 2>&1
killall -9 -u neutron >/dev/null 2>&1
killall -9 -u nova >/dev/null 2>&1
killall -9 -u cinder >/dev/null 2>&1
killall -9 -u designate >/dev/null 2>&1
killall -9 -u glance >/dev/null 2>&1
killall -9 -u trove >/dev/null 2>&1
killall -9 -u sahara >/dev/null 2>&1
killall -9 -u manila >/dev/null 2>&1
killall -9 -u ceilometer >/dev/null 2>&1
killall -9 -u aodh >/dev/null 2>&1
killall -9 -u swift >/dev/null 2>&1

#
# We uninstall all openstack packages
#

echo "Erasing OpenStack Packages"

yum -y erase openstack-glance \
	openstack-utils \
	openstack-selinux \
	openstack-keystone \
	python-psycopg2 \
	qpid-cpp-server \
	qpid-cpp-server-ssl \
	qpid-cpp-client \
	scsi-target-utils \
	sg3_utils \
	openstack-cinder \
	openstack-neutron \
	openstack-neutron-* \
	openstack-nova-* \
	openstack-swift-* \
	openstack-ceilometer-* \
	openstack-aodh-* \
	openstack-heat-* \
	openstack-trove-* \
	openstack-sahara* \
	openstack-manila* \
	openstack-designate* \
	mongodb-server \
	mongodb \
	haproxy \
	rabbitmq-server \
	erlang-* \
	openstack-dashboard \
	openstack-packstack \
	sysfsutils \
	genisoimage \
	libguestfs \
	spice-html5 \
	rabbitmq-server \
	python-django-openstack-auth \
	python-keystone* \
	python-backports \
	python-backports-ssl_match_hostname \
	scsi-target-utils \
	scsi-target-utils-gluster

yum -y erase openstack-puppet-modules openstack-packstack-puppet
yum -y erase qpid-cpp-server qpid-cpp-server-ssl qpid-cpp-client cyrus-sasl cyrus-sasl-md5 cyrus-sasl-plain
yum -y erase rabbitmq-server
yum -y erase bind
rm -rf /var/named

#
# And clean up swift devices if we decided to do it in oir config file
#

if [ $cleanupdeviceatuninstall == "yes" ]
then
	rm -rf /srv/node/$swiftdevice/accounts
	rm -rf /srv/node/$swiftdevice/containers
	rm -rf /srv/node/$swiftdevice/objects
	rm -rf /srv/node/$swiftdevice/tmp
	chown -R root:root /srv/node/
	restorecon -R /srv
	systemctl disable rsyncd.service
	systemctl stop rsyncd.service
	rm -f /etc/rsyncd.conf
fi

#
# Delete OpenStack users and other remaining files
#

echo "Erasing OpenStack Services Users"

userdel -f -r keystone
userdel -f -r glance
userdel -f -r cinder
userdel -f -r neutron
userdel -f -r nova
userdel -f -r mongodb
userdel -f -r ceilometer
userdel -f -r swift
userdel -f -r rabbitmq
userdel -f -r heat
userdel -f -r trove
userdel -f -r qpidd
userdel -f -r aodh
userdel -f -r manila
userdel -f -r designate
userdel -f -r named

echo "Erasing remaining files"

rm -fr /etc/glance \
	/etc/keystone \
	/var/log/glance \
	/var/log/keystone \
	/var/lib/glance \
	/var/lib/keystone \
	/etc/cinder \
	/var/lib/cinder \
	/var/log/cinder \
	/etc/sudoers.d/cinder \
	/etc/tgt \
	/etc/neutron \
	/var/lib/neutron \
	/var/log/neutron \
	/etc/sudoers.d/neutron \
	/etc/nova \
	/etc/heat \
	/etc/trove \
	/var/log/trove \
	/var/cache/trove \
	/var/log/nova \
	/var/lib/nova \
	/etc/sudoers.d/nova \
	/etc/openstack-dashboard \
	/var/log/horizon \
	/etc/sysconfig/mongod \
	/var/lib/mongodb \
	/etc/ceilometer \
	/var/log/ceilometer \
	/var/lib/ceilometer \
	/etc/ceilometer-collector.conf \
	/etc/swift/ \
	/var/lib/swift \
	/tmp/keystone-signing-swift \
	/etc/openstack-control-script-config \
	/var/lib/keystone-signing-swift \
	/var/lib/rabbitmq \
	/var/log/rabbitmq \
	/etc/rabbitmq \
	$dnsmasq_config_file \
	/etc/dnsmasq-neutron.d \
	/var/tmp/packstack \
	/var/lib/keystone-signing-swift \
	/var/lib/qpidd \
	/etc/qpid \
	/var/oslock/cinder \
	/var/oslock/nova \
	/etc/aodh \
	/var/log/aodh \
	/var/lib/aodh \
	/etc/manila \
	/var/log/manila \
	/var/lib/manila \
	/etc/designate \
	/var/lib/designate \
	/var/log/designate \
	/root/keystonerc_*

rm -fr /var/log/{keystone,glance,nova,neutron,cinder,ceilometer,heat,sahara,trove,aodh,manila,designate}*
rm -fr /run/{keystone,glance,nova,neutron,cinder,ceilometer,heat,trove,sahara,aodh,manila,designate}*
rm -fr /run/lock/{keystone,glance,nova,neutron,cinder,ceilometer,heat,trove,sahara,aodh,manila,designate}*
rm -fr /root/.{keystone,glance,nova,neutron,cinder,ceilometer,heat,trove,sahara,aodh,manila,designate}client

rm -f /etc/cron.d/openstack-monitor-crontab
rm -f /etc/cron.d/ceilometer-expirer-crontab
rm -f /var/log/openstack-install.log
rm -fr /var/lib/openstack-dashboard

rm -f /root/keystonerc_admin
rm -f /root/ks_admin_token
rm -f /root/keystonerc_fulladmin

rm -f /usr/local/bin/openstack-control.sh
rm -f /usr/local/bin/openstack-log-cleaner.sh
rm -f /usr/local/bin/openstack-keystone-tokenflush.sh
rm -f /usr/local/bin/openstack-vm-boot-start.sh
rm -f /usr/local/bin/compute-and-instances-full-report.sh
rm -f /usr/local/bin/instance-cpu-metrics-report.sh
rm -f /etc/httpd/conf.d/openstack-dashboard.conf*
rm -f /etc/httpd/conf.d/rootredirect.conf*
rm -f /etc/cron.d/keystone-flush.crontab
rm -f /etc/httpd/conf.d/wsgi-keystone.conf
rm -rf /var/www/cgi-bin/keystone
rm -f /etc/libvirt/qemu/$instance_name_template*.xml

service crond restart

#
# Restore original snmpd configuration
#

if [ $snmpinstall == "yes" ]
then
	if [ -f /etc/snmp/snmpd.conf.pre-openstack ]
	then
		rm -f /etc/snmp/snmpd.conf
		mv /etc/snmp/snmpd.conf.pre-openstack /etc/snmp/snmpd.conf
		service snmpd restart
	else
		service snmpd stop
		yum -y erase net-snmp
		rm -rf /etc/snmp
	fi
	rm -f /usr/local/bin/vm-number-by-states.sh \
	/usr/local/bin/vm-total-cpu-and-ram-usage.sh \
	/usr/local/bin/vm-total-disk-bytes-usage.sh \
	/usr/local/bin/node-cpu.sh \
	/usr/local/bin/node-memory.sh \
	/etc/cron.d/openstack-monitor.crontab \
	/var/tmp/node-cpu.txt \
	/var/tmp/node-memory.txt \
	/var/tmp/vm-cpu-ram.txt \
	/var/tmp/vm-disk.txt \
	/var/tmp/vm-number-by-states.txt
fi

echo "Restaring Apache without Horizon"

service httpd restart
service memcached restart

#
# Clean up iptables
#

echo "Cleaning IPTABLES"

service iptables stop
echo "" > /etc/sysconfig/iptables

#
# Kill all database related software and content, if we choose to do it in our config file
# THIS IS THE PART WHERE READING OUR README IS NOT AND OPTION BUT A NECESSITY
#

if [ $dbinstall == "yes" ]
then

	echo ""
	echo "Uninstalling Database Software"
	echo ""
	case $dbflavor in
	"mysql")
		systemctl stop mariadb
		systemctl disable mariadb
		sync
		sleep 5
		sync
		yum -y erase mariadb-libs mariadb-server-galera mariadb-config mariadb-server \
			mariadb-common mariadb-galera-common mariadb mariadb-errmsg
		userdel -r mysql
		rm -f /root/.my.cnf /etc/my.cnf
		rm -fr /etc/my.cnf.d /var/log/mariadb /var/lib/mysql
		;;
	"postgres")
		service postgresql stop
		sync
		sleep 5
		sync
		yum -y erase postgresql-server postgresql-libs postgresql
		userdel -r postgres
		rm -f /root/.pgpass
		;;
	esac
fi

if [ $cindercleanatuninstall == "yes" ]
then
        echo ""
        echo "Cleaning Up Cinder Volume LV: $cinderlvmname"
        lvremove -f $cinderlvmname 2>/dev/null
fi

if [ $manilacleanatuninstall == "yes" ]
then
        echo ""
        echo "Cleaning Up Manila Volume LV: $manilavg"
        lvremove -f $manilavg 2>/dev/null
fi

#
# Final FULL Clean UP
yum clean all

echo ""
echo "OpenStack Uninstall Complete"
echo ""

