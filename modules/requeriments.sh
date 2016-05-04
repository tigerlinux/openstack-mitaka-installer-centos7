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
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my config file. Aborting !"
	echo ""
	exit 0
fi

#
# Some pre-cleanup first !. Just in order to avoid "Oppssess"
#

rm -rf /tmp/keystone-signing-*
rm -rf /tmp/cd_gen_*

#
# Then we begin some verifications
#

epelinstalled=`rpm -qa|grep epel-release.\*noarch|wc -l`
amiroot=` whoami|grep root|wc -l`
amiarhel7=`cat /etc/redhat-release |grep 7.|wc -l`
internalbridgeinterface=`ifconfig $integration_bridge|grep -c $integration_bridge`
internalbridgepresent=`ovs-vsctl show|grep -i -c bridge.\*$integration_bridge`
oskernelinstalled=`uname -r|grep -c x86_64`

#
# Old bug from JUNO. Commented now, meanwhile we verify if it's really solved
#

echo ""
echo "NOTE: Deactivating SELINUX - Existing bug with NOVA-API"
echo ""

setenforce 0
sed -r -i 's/SELINUX=enforcing/SELINUX=disabled/g' /etc/selinux/config
sed -r -i 's/SELINUX=permissive/SELINUX=disabled/g' /etc/selinux/config

echo ""
	
echo "Installing initial packages"
echo ""

#
# We proceed to install some initial packages
#

yum -y clean all
yum -y install yum-plugin-priorities yum-presto yum-plugin-changelog openstack-packstack
yum -y groupinstall Virtualization-Platform Virtualization-tools
yum -y install libvirt qemu kvm
yum -y install sudo gcc cpp make automake kernel-headers
yum -y install python-keystoneclient python-sqlalchemy python-migrate python-psycopg2 \
	MySQL-python python-tools sysfsutils sg3_utils genisoimage libguestfs glusterfs \
	glusterfs-fuse nfs-utils sudo libguestfs-tools-c

yum -y install boost-program-options perl-DBD-MySQL wxBase wxGTK  wxGTK-gl libtool-ltdl \
	unixODBC python-six python-iso8601 python-babel python-argparse python-oslo-config \
	python-ordereddict python-webob python-memcached python-oauthlib python-routes \
	python-backports python-backports-ssl_match_hostname python-urllib3 python-passlib \
	python-dogpile-core python-dogpile-cache python-jsonschema python-paste \
	python-paste-deploy python-tempita python-chardet python-requests python-stevedore

yum -y install PyPAM python-decorator python-migrate python-prettytable python-keyring \
	python-keystoneclient python-greenlet python-eventlet python-oslo-messaging \
	python-pycadf python-keystone python-httplib2 pyxattr python-swiftclient \
	python-kombu python-qpid pysendfile python-jsonpointer python-jsonpatch \
	python-warlock python-glanceclient python-simplejson python-cinderclient \
	saslwrapper python-saslwrapper python-glance crudini libibverbs librdmacm

yum -y install perl-Config-General python-anyjson python-novaclient python-amqplib \
	python-markdown python-oslo-rootwrap python-suds libyaml PyYAML python-pygments \
	python-cheetah pyparsing python-futures python-lockfile python-devel numpy-f2py \
	scipy python-networkx-core python-taskflow python-cinder python-markupsafe \
	python-jinja2 python-pyasn1 python-boto python-cmd2 python-cliff

yum -y install python-neutronclient python-websockify pysnmp python-croniter python-beaker \
	python-mako python-alembic python-ply python-msgpack python-jsonpath-rw \
	python-ceilometer python-libguestfs python-neutron python-ceilometerclient \
	python-troveclient python-versiontools python-bson python-pymongo python-simplegeneric \
	python-logutils python-werkzeug python-flask python-webtest python-ipaddr \
	python-wsme python-singledispatch python-pecan 

yum -y install python-ceilometerclient python-cinderclient python-glanceclient \
	python-heatclient python-openstackclient python-swiftclient python-neutronclient \
	python-novaclient python-configobj python-lesscpy python-netifaces

yum -y install python2-PyMySQL python-psycopg2

yum -y install scsi-target-utils scsi-target-utils-gluster

yum -y install libguestfs-tools libguestfs

yum -y erase firewalld
yum -y install iptables iptables-services iptables-utils

yum -y install python-openstackclient

yum -y install spice-html5

#
# From v 1.0.2 - Liberty Installer
yum -y install ntfsprogs ntfs-3g

#
# We configure tuned and ksm
#
	
yum -y install tuned tuned-utils
echo "virtual-host" > /etc/tuned/active_profile
chkconfig ksm on
chkconfig ksmtuned on
chkconfig tuned on

service ksm restart
service ksmtuned restart
service tuned restart

#
# More verification work
#

testlibvirt=`rpm -qi libvirt|grep -ci "is not installed"`

if [ $testlibvirt == "1" ]
then
	echo ""
	echo "Libvirt installation failed. Aborting !"
	echo ""
	exit 0
fi

packstackinstalled=`rpm -qa|grep openstack-packstack.\*noarch|grep -v puppet|wc -l`
searchtestnova=`yum search openstack-nova-common|grep openstack-nova-common.\*noarch|wc -l`


if [ $amiarhel7 == "1" ]
then
	echo ""
	echo "RHEL7/CENTOS7 Verified OK"
	echo ""
else
	echo ""
	echo "Can't verify the O/S pre-requirement. Aborting !"
	echo ""
fi

if [ $epelinstalled == "1" ]
then
	echo ""
	echo "EPEL 7 Verified OK"
else
	echo ""
	echo "Can't verify EPEL 7 installation. Aborting !"
	echo ""
	exit 0
fi

if [ $amiroot == "1" ]
then
	echo ""
	echo "We are running as root. OK"
	echo ""
else
	echo ""
	echo "WARNING: We need to run as ROOT. Aborting !"
	echo ""
	exit 0
fi

if [ $oskernelinstalled == "1" ]
then
	echo ""
	echo "Right Kernel OK"
	echo ""
else
	echo ""
	echo "We seem to have an incorrect Kernel Version. Aborting"
	echo ""
	exit 0
fi

if [ $packstackinstalled == "1" ]
then
	echo ""
	echo "Packstack verified OK"
	echo ""
else
	echo ""
	echo "Packstack presence not verified. We don't have RDO Repos enabled. Aborting !"
	echo ""
	exit 0
fi

if [ $searchtestnova == "1" ]
then
	echo ""
	echo "RDO Repos OK"
	echo ""
else
	echo ""
	echo "RDO Repos NOT OK. Aborting"
	echo ""
	exit 0
fi

if [ $internalbridgeinterface == "1" ]
then
	echo ""
	echo "br-int interface OK"
	echo ""
else
	echo ""
	echo "br-int interface not present. Aborting !"
	echo ""
	exit 0
fi

if [ $internalbridgepresent == "1" ]
then
	echo ""
	echo "OVS Integration Bridge Present. OK"
	echo ""
else
	echo ""
	echo "OVS Integration Bridge NOT PRESENT. Aborting"
	echo ""
	exit 0
fi

echo ""
echo "Initial pre-requirements OK"
echo ""

#
# Then we proceed to configure Libvirt and iptables, and also to verify proper installation
# of libvirt. If that fails, we stop here !
#

echo "Configuring libvirt and cleaning up IPTABLES rules"

if [ -f /etc/openstack-control-script-config/libvirt-installed ]
then
	echo "Libvirt and pre-requirements already installed"
else
	service libvirtd stop
	rm /etc/libvirt/qemu/networks/autostart/default.xml
	rm /etc/libvirt/qemu/networks/default.xml
	service iptables stop
	echo “” > /etc/sysconfig/iptables
	cat ./libs/iptables > /etc/sysconfig/iptables
	service libvirtd start
	chkconfig libvirtd on
	service iptables stop >/dev/null 2>&1
	service iptables start >/dev/null 2>&1
	service iptables save >/dev/null 2>&1
	service iptables restart >/dev/null 2>&1

	sed -i.ori 's/#listen_tls = 0/listen_tls = 0/g' /etc/libvirt/libvirtd.conf
	sed -i 's/#listen_tcp = 1/listen_tcp = 1/g' /etc/libvirt/libvirtd.conf
	sed -i 's/#auth_tcp = "sasl"/auth_tcp = "none"/g' /etc/libvirt/libvirtd.conf
	sed -i.ori 's/#LIBVIRTD_ARGS="--listen"/LIBVIRTD_ARGS="--listen"/g' /etc/sysconfig/libvirtd

	systemctl restart libvirtd
	iptables -A INPUT -p tcp -m multiport --dports 22 -j ACCEPT
	iptables -A INPUT -p tcp -m multiport --dports 16509 -j ACCEPT
	service iptables save

	date > /etc/openstack-control-script-config/libvirt-installed
	echo ""
	echo "Libvirt and dependencies installed"
	echo ""
fi

