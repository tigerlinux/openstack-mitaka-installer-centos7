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

if [ -f /etc/openstack-control-script-config/broker-installed ]
then
	echo ""
	echo "This module was already completed. Exiting !"
	echo ""
	exit 0
fi

echo ""
echo "Installing Messagebroker Packages"

#
# Depending of our selection, we'll install either qpid or rabbitmq as message broker
#
# The proccess here will not only install the broker, but also configure it with proper
# access permissions. Finally, the proccess will verify proper installation, and if it
# encounters something wrong, it will fail and make stop the main installer.
#

case $brokerflavor in
"qpid")
	yum -y install compat-qpid-cpp-server \
		compat-qpid-cpp-server-ssl \
		compat-qpid-cpp-client \
		cyrus-sasl \
		cyrus-sasl-md5 \
		cyrus-sasl-plain

	yum -y erase cyrus-sasl-gssapi

	echo ""
	echo "QPID Installed"
	echo ""

	echo "Configuring QPID"

	echo "auth=yes" > /etc/qpid/qpidd.conf
	echo "realm=QPID" >> /etc/qpid/qpidd.conf

	echo "$brokerpass"|saslpasswd2 -f /var/lib/qpidd/qpidd.sasldb -u QPID $brokeruser -p

	chown -R qpidd.qpidd /var/lib/qpidd/

	service saslauthd restart
	chkconfig saslauthd on

	echo "Done"

	echo ""
	echo "Staring QPID"

	chkconfig qpidd on
	service qpidd stop
	service qpidd start

	echo "Done"
	echo ""

	qpidtest=`rpm -qi compat-qpid-cpp-server|grep -ci "is not installed"`
	if [ $qpidtest == "1" ]
	then
		echo ""
		echo "QPID Installation FAILED. Aborting !"
		echo ""
		exit 0
	else
		date > /etc/openstack-control-script-config/broker-installed
	fi
	;;

"rabbitmq")

	yum -y install rabbitmq-server

	echo "RABBITMQ_NODE_IP_ADDRESS=0.0.0.0" > /etc/rabbitmq/rabbitmq-env.conf

	chkconfig rabbitmq-server on
	sync
	sleep 5
	sync
	service rabbitmq-server start
	
	# This is an ugly but necessary patch. In Centos 7, sometimes Rabbit does not
	# start correctly, so we have to make it restart in a loop until it really
	# starts the right way.
	mytest=0
	mycounter=1
	while [ $mytest == "0" ]
	do
		echo "Verifying RabbitMQ - Try $mycounter"
		service rabbitmq-server restart
		sleep 1
		mytest=`rabbitmqctl status|grep -c "erlang_version"`
		let mycounter=mycounter+1
	done

	echo "RabbitMQ OK"

	rabbitmqctl status

	sleep 2

	rabbitmqctl add_vhost $brokervhost
	rabbitmqctl list_vhosts

	rabbitmqctl add_user $brokeruser $brokerpass
	rabbitmqctl list_users

	rabbitmqctl set_permissions -p $brokervhost $brokeruser ".*" ".*" ".*"
	rabbitmqctl list_permissions -p $brokervhost

	rabbitmqtest=`rpm -qi rabbitmq-server|grep -ci "is not installed"`
	if [ $rabbitmqtest == "1" ]
	then
		echo ""
		echo "RabbitMQ Installation Failed. Aborting !"
		echo ""
		exit 0
	else
		vhosttest=`rabbitmqctl list_vhosts|grep -c $brokervhost`
		if [ $vhosttest == "0" ]
		then
			echo ""
			echo "RabbitMQ Config FAILED. Aborting !"
			echo ""
			exit 0
		fi
		
		date > /etc/openstack-control-script-config/broker-installed
	fi

	;;
esac

#
# If the broker installation was successfull, we proceed to apply IPTABLES rules
#

echo "Applying IPTABLES Rules"

iptables -I INPUT -p tcp -m tcp --dport 5672 -j ACCEPT
service iptables save

echo "Done"

echo ""
echo "Message Broker Installed and Configured"
echo ""


