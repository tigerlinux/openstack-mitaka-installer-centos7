#!/bin/bash
#
# Unattended installer for OpenStack.
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Main Installer Script
# Version: 1.0.1.el7 "Lynx Pardinus"
# May 05, 2016
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
# This is our main installation script. It's function is basically read the main configuration file
# in "./configs" directory, source all installation variables, and then install every component in
# the right order. Normally the order is as follows:
# 1.- Basic python libraries and other base packages. Libvirt/qemu/kvm, sudo, etc.
# 2.- Message Broker (either rabbit or qpid - only if it's a controller).
# 3.- Database installation, configuration and provisioning (if it's a controller).
# 4.- Extra libraries (only on debian/ubuntu based installs).
# 5.- Keystone (if it's a controller, installs the sofwtare, in other cases, justo provision the en-
#     vironment files
# 6.- Application Modules (if apply and where apply) in order:
#     - Swift.
#     - Glance.
#     - Cinder.
#     - Neutron.
#     - Nova.
#     - Ceilometer.
#     - Heat.
#     - Trove.
#     - Sahara.
#     - Horizon.
# 7.- Basic SNMP Support.
# 8.- Post-install with maintenance crontabs and scripts
#
# This installation tool will allow you to construct an OpenStack cloud with the following possible
# configurations:
# - Monolitic ALL-IN-ONE OpenStack Server (basically an ALL-Services controller/compute).
# - Distributed Cloud with a Controller/Compute and several compute nodes.
# - Distributed Cloud with a Pure Controller and several compute nodes.
# - Fully distributed cloud with controller services distributed in many nodes, and several compute nodes
#
# The behaviour of this script is completelly controlled in the ./config/main-config.rc file. By properlly
# configuring this file, you can deploy your cloud the way you want.
#

case $1 in
"install")

	if [ -f ./configs/main-config.rc ]
	then
		source ./configs/main-config.rc
		mkdir -p /etc/openstack-control-script-config
		date > /etc/openstack-control-script-config/install-init-date-and-time
		chown -R root.root *
		find . -name "*" -type f -exec chmod 644 "{}" ";"
		find . -name "*.sh" -type f -exec chmod 755 "{}" ";"
	else
		echo "I can't access my own configuration"
		echo "Please check you are executing the installer in its correct directory"
		echo "Aborting !!!!."
		echo ""
		exit 0
	fi

	clear

	echo ""
	echo "OPENSTACK UNATTENDED INSTALLER"
	echo "Flavor: OpenStack MITAKA for Centos 7"
	echo "Made by: Reynaldo R. Martinez P."
	echo "E-Mail: TigerLinux@Gmail.com"
	echo "Version 1.0.1.el7 \"Lynx Pardinus\" - May 05, 2016"
	echo ""
	echo "I'll verify all requiremens"
	echo "If any requirement is not met, I'll stop and inform what's missing"
	echo ""
	echo "Requirements"
	echo "- OS: Centos 7 x86_64 fully updated"
	echo "- This script must be executed by root account (don't use sudo please)"
	echo "- Centos 7 original repositories must be enabled and available"
	echo "- Epel 7 repository must be enabled and available"
	echo "- OpenStack RDO repositories for MITAKA also enabled and available"
	echo "- OpenVSwitch must be installed and configured with at least br-int bridge"
	echo "- If you wish to install swift, the filesystem should be mounted in /srv/node"
	echo ""
	echo "NOTE: You can use the tee command if you want to log all installer actions. Example:"
	echo "./main-installer.sh install | tee -a /var/log/my_install_log.log"
	echo ""

	case $2 in
	auto|AUTO)
		echo "Automated mode activated. No additional questions will be made"
		;;
	*)
		echo -n "Do you wish to continue ? [y/n]:"
		read -n 1 answer
		echo ""
		case $answer in
		y|Y)
			echo ""
			echo "Starting verifications"
			echo ""
			;;
		*)
			echo ""
			echo "Aborting by user request !!!"
			echo ""
			exit 0
			;;
		esac
		;;
	esac

	
	echo ""
	echo "Installing requirements and performing more validations"
	echo ""

	./modules/requeriments.sh
	
	if [ -f /etc/openstack-control-script-config/libvirt-installed ]
	then
		echo ""
		echo "Requeriments installed and initial validations done"
		echo "I'll continue with the OpenStack modules installation"
		echo ""
	else
		echo ""
		echo "Something bad happened. Validations failed"
		echo "Aborting the installation !!"
		echo ""
		exit 0
	fi

	echo "Ready... let's continue working"
	echo ""

	rm -rf /tmp/keystone-signing-*
	rm -rf /tmp/cd_gen_*

	if [ $messagebrokerinstall == "yes" ]
	then
		echo ""
		echo "Installing message broker"
		./modules/messagebrokerinstall.sh
		
		if [ -f /etc/openstack-control-script-config/broker-installed ]
		then
			echo ""
			echo "Ready"
			echo ""
		else
			echo ""
			echo "Message broker installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	echo ""
	echo "Installing database support"
	echo ""

	./modules/databaseinstall.sh

	if [ -f /etc/openstack-control-script-config/db-installed ]
	then
		echo ""
		echo "Database support ready"
		echo ""
	else
		echo ""
		echo "Database support installation failed. Abroting !!"
		echo ""
		exit 0
	fi


	if [ $keystoneinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK KEYSTONE"

		./modules/keystoneinstall.sh

		if [ -f /etc/openstack-control-script-config/keystone-installed ]
		then
			echo "OPENSTACK KEYSTONE INSTALLED"
		else
			echo ""
			echo "Keystone installation failed. Aborting !!"
			echo ""
			exit 0
		fi

	else
		OS_URL="http://$keystonehost:35357/v3"
		OS_USERNAME=$keystoneadminuser
		OS_TENANT_NAME=$keystoneadminuser
		OS_PASSWORD=$keystoneadminpass
		OS_AUTH_URL="http://$keystonehost:5000/v3"
		OS_VOLUME_API_VERSION=2
		OS_PROJECT_DOMAIN_NAME=$keystonedomain
		OS_USER_DOMAIN_NAME=$keystonedomain
		OS_IDENTITY_API_VERSION=3

		echo "# export OS_URL=$SERVICE_ENDPOINT" > $keystone_admin_rc_file
		echo "# export OS_TOKEN=$SERVICE_TOKEN" >> $keystone_admin_rc_file
		echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_admin_rc_file
		echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_admin_rc_file
		echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
		echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_admin_rc_file
		echo "export OS_AUTH_URL=$OS_AUTH_URL" >> $keystone_admin_rc_file
		echo "export OS_VOLUME_API_VERSION=2" >> $keystone_admin_rc_file
		echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_admin_rc_file
		echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file 
		echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_admin_rc_file
		echo "export OS_AUTH_VERSION=3" >> $keystone_admin_rc_file
		echo "PS1='[\u@\h \W(keystone_admin)]\$ '" >> $keystone_admin_rc_file

        	OS_AUTH_URL_FULLADMIN="http://$keystonehost:35357/v3"

        	echo "# export OS_URL=$SERVICE_ENDPOINT" > $keystone_fulladmin_rc_file
        	echo "# export OS_TOKEN=$SERVICE_TOKEN" >> $keystone_fulladmin_rc_file
        	echo "export OS_USERNAME=$OS_USERNAME" >> $keystone_fulladmin_rc_file
        	echo "export OS_PASSWORD=$OS_PASSWORD" >> $keystone_fulladmin_rc_file
        	echo "export OS_TENANT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
        	echo "export OS_PROJECT_NAME=$OS_TENANT_NAME" >> $keystone_fulladmin_rc_file
        	echo "export OS_AUTH_URL=$OS_AUTH_URL_FULLADMIN" >> $keystone_fulladmin_rc_file
        	echo "export OS_VOLUME_API_VERSION=2" >> $keystone_fulladmin_rc_file
		echo "export OS_IDENTITY_API_VERSION=3" >> $keystone_fulladmin_rc_file
                echo "export OS_PROJECT_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
                echo "export OS_USER_DOMAIN_NAME=$keystonedomain" >> $keystone_fulladmin_rc_file
		echo "export OS_AUTH_VERSION=3" >> $keystone_fulladmin_rc_file
        	echo "PS1='[\u@\h \W(keystone_fulladmin)]\$ '" >> $keystone_fulladmin_rc_file

		mkdir -p /etc/openstack-control-script-config
		date > /etc/openstack-control-script-config/keystone-installed
		date > /etc/openstack-control-script-config/keystone-extra-idents
	fi

	if [ $swiftinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK SWIFT"

		./modules/swiftinstall.sh

		if [ -f /etc/openstack-control-script-config/swift-installed ]
		then
			echo "OPENSTACK SWIFT INSTALLED"
		else
			echo ""
			echo "Swift installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	if [ $glanceinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK GLANCE"

		./modules/glanceinstall.sh

		if [ -f /etc/openstack-control-script-config/glance-installed ]
		then
			echo "OPENSTACK GLANCE INSTALLED"
		else
			echo ""
			echo "Glance installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	if [ $cinderinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK CINDER"

		./modules/cinderinstall.sh

		if [ -f /etc/openstack-control-script-config/cinder-installed ]
		then
			echo "OPENSTACK CINDER INSTALLED"
		else
			echo ""
			echo "Cinder installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	if [ $neutroninstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK NEUTRON"

		./modules/neutroninstall.sh

		if [ -f /etc/openstack-control-script-config/neutron-installed ]
		then
			echo "OPENSTACK NEUTRON INSTALLED"
		else
			echo ""
			echo "Neutron installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	if [ $novainstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK NOVA"

		./modules/novainstall.sh

		if [ -f /etc/openstack-control-script-config/nova-installed ]
		then
			echo "OPENSTACK NOVA INSTALLED"
		else
			echo ""
			echo "Nova installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	if [ $ceilometerinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK CEILOMETER"

		./modules/ceilometerinstall.sh

		if [ -f /etc/openstack-control-script-config/ceilometer-installed ]
		then
			echo "OPENSTACK CEILOMETER INSTALLED"
		else
			echo ""
			echo "Ceilometer installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

        if [ $heatinstall == "yes" ]
        then
                echo ""
                echo "Installing OPENSTACK HEAT"

                ./modules/heatinstall.sh

                if [ -f /etc/openstack-control-script-config/heat-installed ]
                then
                        echo "OPENSTACK HEAT INSTALLED"
                else
                        echo ""
                        echo "Heat installation failed. Aborting !!"
                        echo ""
                        exit 0
                fi
        fi

	if [ $troveinstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK TROVE"
		
		./modules/troveinstall.sh
		
		if [ -f /etc/openstack-control-script-config/trove-installed ]
		then
			echo "OPENSTACK TROVE INSTALLED"
		else
			echo ""
			echo "Trove installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi 

	if [ $saharainstall == "yes" ]
	then
                echo ""
                echo "Installing OPENSTACK SAHARA"
		
                ./modules/saharainstall.sh
		
                if [ -f /etc/openstack-control-script-config/sahara-installed ]
                then
                        echo "OPENSTACK SAHARA INSTALLED"
                else
                        echo ""
                        echo "Sahara installation failed. Aborting !!"
                        echo ""
                        exit 0
                fi
	fi

	if [ $snmpinstall == "yes" ]
	then
		echo ""
		echo "INSTALLING SNMP SUPPORT"

		./modules/snmpinstall.sh

		if [ -f /etc/openstack-control-script-config/snmp-installed ]
		then
			echo "SNMP SUPPORT INSTALLED"
		else
			echo ""
			echo "SNMP Support failed to install, but because this is NOT critical,"
			echo "we will continue the installation"
			echo ""
		fi
	fi

	if [ $horizoninstall == "yes" ]
	then
		echo ""
		echo "Installing OPENSTACK HORIZON"

		./modules/horizoninstall.sh

		if [ -f /etc/openstack-control-script-config/horizon-installed ]
		then
			echo "OPENSTACK HORIZON INSTALLED"
		else
			echo ""
			echo "Horizon installation failed. Aborting !!"
			echo ""
			exit 0
		fi
	fi

	echo ""
	echo "Executing Post Install"
	./modules/postinstall.sh

	date > /etc/openstack-control-script-config/install-end-date-and-time

	echo ""
	echo "OPENSTACK INSTALLATION FINISHED"
	echo ""
	
	;;
"uninstall")

	if [ -f ./configs/main-config.rc ]
	then
		source ./configs/main-config.rc
	else
                echo "I can't access my own configuration"
                echo "Please check you are executing the installer in its correct directory"
                echo "Aborting !!!!."
                echo ""
		exit 0
	fi

	echo ""
	echo "All openstack related content will be erased from this server"
	echo ""
	case $2 in
	auto|AUTO)
		echo "Automated mode activated"
		;;
	*)
		echo -n "Are you sure you want to continue ? [y/n]:"
		read -n 1 answer
		case $answer in
		y|Y)
			echo ""
			echo "Uninstalling OpenStack services, packages and configurations"
			echo ""
			;;
		*)
			echo ""
			echo "Aborted by user request"
			echo ""
			exit 0
			;;
		esac
	esac
	./modules/uninstall.sh
	;;
*)
	echo ""
	echo "Usage: $0 install | uninstall [auto]"
	echo ""
	;;
esac

