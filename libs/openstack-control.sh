#!/bin/bash
#
# Unattended installer for OpenStack. - Centos 7
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Service control script
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

if [ ! -d /etc/openstack-control-script-config ]
then
	echo ""
	echo "Control file not found: /etc/openstack-control-script-config"
	echo "Aborting !"
	echo ""
	exit 0
fi

if [ -f /etc/openstack-control-script-config/nova-console-svc ]
then
	consolesvc=`/bin/cat /etc/openstack-control-script-config/nova-console-svc`
fi

# Keystone. Index=0
svckeystone=(
"
httpd
"
)

# Swift. Index=1
svcswift=(
"
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
"
)

# Glance. Index=2
svcglance=(
"
openstack-glance-registry
openstack-glance-api
"
)

# Cinder. Index=3
svccinder=(
"
openstack-cinder-api
openstack-cinder-scheduler
openstack-cinder-volume
"
)

# Neutron. Index=4
if [ -f /etc/openstack-control-script-config/neutron-full-installed ]
then
	if [ -f /etc/openstack-control-script-config/neutron-full-installed-metering ]
	then
		metering="neutron-metering-agent"
	else
		metering=""
	fi
	if [ -f /etc/openstack-control-script-config/neutron-full-installed-vpnaas ]
	then
		svcneutron=(
			"
			neutron-ovs-cleanup
			neutron-openvswitch-agent
			neutron-metadata-agent
			neutron-dhcp-agent
			neutron-lbaasv2-agent
			neutron-vpn-agent
			$metering
			neutron-server
			"
		)
	else
		svcneutron=(
			"
                        neutron-ovs-cleanup
                        neutron-openvswitch-agent
                        neutron-metadata-agent
                        neutron-l3-agent
                        neutron-dhcp-agent
                        neutron-lbaasv2-agent
			$metering
                        neutron-server
			"
		)
	fi
else
	if [ -f /etc/openstack-control-script-config/neutron-installed-dhcp-agent ]
	then
		svcneutron=(
			"
			neutron-ovs-cleanup
			neutron-openvswitch-agent
			neutron-l3-agent
			neutron-metadata-agent
			neutron-dhcp-agent
			"
		)
	else
		svcneutron=(
			"
			neutron-ovs-cleanup
			neutron-openvswitch-agent
			neutron-l3-agent
			neutron-metadata-agent
			"
		)
	fi
fi

# Nova. Index=5
if [ -f /etc/openstack-control-script-config/nova-full-installed ]
then
	if [ -f /etc/openstack-control-script-config/nova-without-compute ]
	then
		svcnova=(
			"
			openstack-nova-api
			openstack-nova-cert
			openstack-nova-scheduler
			openstack-nova-conductor
			openstack-nova-consoleauth
			$consolesvc
			"
		)
	else
		svcnova=(
			"
			openstack-nova-api
			openstack-nova-cert
			openstack-nova-scheduler
			openstack-nova-conductor
			openstack-nova-consoleauth
			$consolesvc
			openstack-nova-compute
			"
		)
	fi
else
	svcnova=(
		"
		openstack-nova-compute
		"
	)
fi

# Ceilometer. Index=6
if [ -f /etc/openstack-control-script-config/ceilometer-installed-alarms ]
then
	alarm1="openstack-aodh-api"
	alarm2="openstack-aodh-evaluator"
	alarm3="openstack-aodh-notifier"
	alarm4="openstack-aodh-listener"
else
	alarm1=""
	alarm2=""
	alarm3=""
	alarm4=""
fi

if [ -f /etc/openstack-control-script-config/ceilometer-full-installed ]
then
	if [ -f /etc/openstack-control-script-config/ceilometer-without-compute ]
	then
		svcceilometer=(
			"
			openstack-ceilometer-central
			openstack-ceilometer-api
			openstack-ceilometer-collector
			openstack-ceilometer-notification
			openstack-ceilometer-polling
			$alarm1
			$alarm2
			$alarm3
			$alarm4
			"
		)
	else
		svcceilometer=(
			"
			openstack-ceilometer-compute
			openstack-ceilometer-central
			openstack-ceilometer-api
			openstack-ceilometer-collector
			openstack-ceilometer-notification
			openstack-ceilometer-polling
			$alarm1
			$alarm2
			$alarm3
			$alarm4
			"
		)
	fi
else
	svcceilometer=(
		"
		openstack-ceilometer-compute
		"
	)
fi

# Heat. Index=7
svcheat=(
"
openstack-heat-api
openstack-heat-api-cfn
openstack-heat-engine
"
)

# Trove. Index=8
svctrove=(
"
openstack-trove-api
openstack-trove-taskmanager
openstack-trove-conductor
"
)

# Sahara. Index=9
svcsahara=(
"
openstack-sahara-all
"
)

# Manila. Index=10
svcmanila=(
"
openstack-manila-api
openstack-manila-scheduler
openstack-manila-share
"
)

# Designate. Index=11
if [ -f /etc/openstack-control-script-config/designate-sink-installed ]
then
	svcdesignate=(
	"
	designate-api
	designate-central
	designate-mdns
	designate-pool-manager
	designate-zone-manager
	designate-sink
	"
	)
else
	svcdesignate=(
	"
	designate-api
	designate-central
	designate-mdns
	designate-pool-manager
	designate-zone-manager
	"
	)
fi

#
# Our Service Indexes:
#
# Keystone = 0
# Swift = 1
# Glance = 2
# Cinder = 3
# Neutron = 4
# Nova = 5
# Ceilometer = 6
# Heat = 7
# Trove = 8
# Sahara = 9
# Manila = 10
# Designate = 11
#

# Now, we create a super array with all services:

servicesstart=("${svckeystone[@]}")				# Index 0 - Keystone
servicesstart=("${servicesstart[@]}" "${svcswift[@]}")		# Index 1 - Swift
servicesstart=("${servicesstart[@]}" "${svcglance[@]}")		# Index 2 - Glance
servicesstart=("${servicesstart[@]}" "${svccinder[@]}")		# Index 3 - Cinder
servicesstart=("${servicesstart[@]}" "${svcneutron[@]}")	# Index 4 - Neutron
servicesstart=("${servicesstart[@]}" "${svcnova[@]}")		# Index 5 - Nova
servicesstart=("${servicesstart[@]}" "${svcceilometer[@]}")	# Index 6 - Ceilometer
servicesstart=("${servicesstart[@]}" "${svcheat[@]}")		# Index 7 - Heat
servicesstart=("${servicesstart[@]}" "${svctrove[@]}")		# Index 8 - Trove
servicesstart=("${servicesstart[@]}" "${svcsahara[@]}")		# Index 9 - Sahara
servicesstart=("${servicesstart[@]}" "${svcmanila[@]}")         # Index 10 - Manila
servicesstart=("${servicesstart[@]}" "${svcdesignate[@]}")	# Index 11 - Manila

moduleliststart=""
moduleliststop=""

# Index 0 - Keystone
if [ -f /etc/openstack-control-script-config/keystone ]
then
	moduleliststart="$moduleliststart 0"
fi

# Index 1 - Swift
if [ -f /etc/openstack-control-script-config/swift ]
then
	moduleliststart="$moduleliststart 1"
fi

# Index 2 - Glance
if [ -f /etc/openstack-control-script-config/glance ]
then
	moduleliststart="$moduleliststart 2"
fi

# Index 3 - Cinder
if [ -f /etc/openstack-control-script-config/cinder ]
then
	moduleliststart="$moduleliststart 3"
fi

# Index 4 - Neutron
if [ -f /etc/openstack-control-script-config/neutron ]
then
	moduleliststart="$moduleliststart 4"
fi

# Index 5 - Nova
if [ -f /etc/openstack-control-script-config/nova ]
then
	moduleliststart="$moduleliststart 5"
fi

# Index 6 - Ceilometer
if [ -f /etc/openstack-control-script-config/ceilometer ]
then
	moduleliststart="$moduleliststart 6"
fi

# Index 7 - Heat
if [ -f /etc/openstack-control-script-config/heat ]
then
	moduleliststart="$moduleliststart 7"
fi

# Index 8 - Trove
if [ -f /etc/openstack-control-script-config/trove ]
then
	moduleliststart="$moduleliststart 8"
fi

# Index 9 - Sahara
if [ -f /etc/openstack-control-script-config/sahara ]
then
	moduleliststart="$moduleliststart 9"
fi

# Index 10 - Manila
if [ -f /etc/openstack-control-script-config/manila ]
then
        moduleliststart="$moduleliststart 10"
fi

# Index 11 - Designate
if [ -f /etc/openstack-control-script-config/designate ]
then
        moduleliststart="$moduleliststart 11"
fi

#
# Now, if we used $2 (second paramater - optional) we can change the index to the
# one of the specific service we want to start/stop/restart/status/etc.
#
case $2 in
keystone)
	# Index 0
	if [ -f /etc/openstack-control-script-config/keystone ]
	then
		moduleliststart="0"
	fi
	;;
swift)
	# Index 1
	if [ -f /etc/openstack-control-script-config/swift ]
	then
		moduleliststart="1"
	fi
	;;
glance)
	# Index 2
	if [ -f /etc/openstack-control-script-config/glance ]
	then
		moduleliststart="2"
	fi
	;;
cinder)
	# Index 3
	if [ -f /etc/openstack-control-script-config/cinder ]
	then
		moduleliststart="3"
	fi
	;;
neutron)
	# Index 4
	if [ -f /etc/openstack-control-script-config/neutron ]
	then
		moduleliststart="4"
	fi
	;;
nova)
	# Index 5
	if [ -f /etc/openstack-control-script-config/nova ]
	then
		moduleliststart="5"
	fi
	;;
ceilometer)
	# Index 6
	if [ -f /etc/openstack-control-script-config/ceilometer ]
	then
		moduleliststart="6"
	fi
	;;
heat)	
	# Index 7
	if [ -f /etc/openstack-control-script-config/heat ]
	then
		moduleliststart="7"
	fi
	;;
trove)
	# Index 8
	if [ -f /etc/openstack-control-script-config/trove ]
	then
		moduleliststart="8"
	fi
	;;
sahara)
	# Index 9
	if [ -f /etc/openstack-control-script-config/sahara ]
	then
		moduleliststart="9"
	fi
	;;
manila)
        # Index 10
        if [ -f /etc/openstack-control-script-config/manila ]
        then
                moduleliststart="10"
        fi
        ;;
designate)
        # Index 11
        if [ -f /etc/openstack-control-script-config/designate ]
        then
                moduleliststart="11"
        fi 
        ;;
esac

moduleliststop=`echo $moduleliststart|tac -s' '`

for svc in $moduleliststop
do
	servicesstop[$svc]=`echo ${servicesstart[$svc]}|tac -s' '`
done

#
# At this point, we have all our services lists. Now, we define 
# start/stop/status/enable/disable functions
#

startsvc(){
	for module in $moduleliststart
	do
		for i in ${servicesstart[$module]}
		do
			echo "Starting Service: $i"
			systemctl start $i
		done
	done
}

stopsvc(){
        for module in $moduleliststop
        do
                for i in ${servicesstop[$module]}
                do
			echo "Stopping Service: $i"
                        systemctl stop $i
                done
        done	
}

enablesvc(){
	for module in $moduleliststart
	do
		for i in ${servicesstart[$module]}
		do
			echo "Enabling Service: $i"
			systemctl enable $i
		done
	done
}

disablesvc(){
	for module in $moduleliststart
	do
		for i in ${servicesstart[$module]}
		do
			echo "Disabling Service: $i"
			systemctl disable $i
		done
	done
}

statussvc(){
	for module in $moduleliststart
	do
		for i in ${servicesstart[$module]}
		do
			systemctl -n 0 status $i
		done
	done
}

#
# Finally, our main case
#
case $1 in
start)
	startsvc
	;;
stop)
	stopsvc
	;;
restart)
	stopsvc
	startsvc
	;;
enable)
	enablesvc
	;;
disable)
	disablesvc
	;;
status)
	statussvc
	;;
*)
	echo ""
	echo "Usage: $0 start, stop, status, restart, enable, or disable:"
	echo "start:    Starts all OpenStack Services"
	echo "stop:     Stops All OpenStack Services"
	echo "restart:  Re-Starts all OpenStack Services"
	echo "enable:   Enable all OpenStack Services"
	echo "disable:  Disable all OpenStack Services"
	echo "status:   Show the status of all OpenStack Services"
	echo ""
	;;
esac
