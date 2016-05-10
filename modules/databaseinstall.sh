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
# First, we source our config file.
#

if [ -f ./configs/main-config.rc ]
then
	source ./configs/main-config.rc
	mkdir -p /etc/openstack-control-script-config
else
	echo "Can't access my configuration file. Aborting !"
	echo ""
	exit 0
fi

#
# If we configured the "dbpopulate" variable to "no", we basically
# assume all database related procedures are completed
#

if [ $dbpopulate == "no" ]
then
	echo "We will NOT populate OpenStack Databases"
	date > /etc/openstack-control-script-config/db-installed
	exit 0
fi

if [ -f /etc/openstack-control-script-config/db-installed ]
then
	echo ""
	echo "Database Support already installed. Exiting !."
	echo ""
	exit 0
fi

#
# If we are going to install database services (dbinstall=yes), then, depending of what
# we choose as "dbflavor", we proceed to install and configure the software and it's root
# access.
#
#
# At the end of this sequence, we test with one of the databases (horizon) so we can decide
# if the proccess was successfull or not
#

if [ $dbinstall == "yes" ]
then
	echo "Proceding to install database software"
	case $dbflavor in
	"mysql")
		echo "Installing Local MariaDB Software"
		rm /root/.my.cnf
		yum -y erase mysql
		yum -y install mariadb-galera-server mariadb-galera-common mariadb-galera galera
		yum -y install openstack-utils
		crudini --set /etc/my.cnf.d/server.cnf mysqld max_allowed_packet 256M
		sed -i -r 's/^bind-address.*=.*0.0.0.0/bind-address=0.0.0.0\nmax_connections=1000/' /etc/my.cnf.d/galera.cnf
		systemctl enable mariadb.service
		systemctl start mariadb.service
		/usr/bin/mysqladmin -u $mysqldbadm password $mysqldbpassword > /dev/null 2>&1
		/usr/bin/mysqladmin -u $mysqldbadm -h $dbbackendhost password $mysqldbpassword > /dev/null 2>&1
		sleep 5
		echo "[client]" > /root/.my.cnf
		echo "user=$mysqldbadm" >> /root/.my.cnf
		echo "password=$mysqldbpassword" >> /root/.my.cnf
		echo "GRANT ALL PRIVILEGES ON *.* TO '$mysqldbadm'@'%' IDENTIFIED BY '$mysqldbpassword' WITH GRANT OPTION;"|mysql
		echo "FLUSH PRIVILEGES;"|mysql
		iptables -A INPUT -p tcp -m multiport --dports $mysqldbport -j ACCEPT
		service iptables save
		echo "MariaDB Installed"
		;;
	"postgres")
		echo "Installing Local PostgreSQL Software"
		yum -y install postgresql-server
		service postgresql initdb
		service postgresql start
		chkconfig postgresql on
		sleep 5
		su - $psqldbadm -c "echo \"ALTER ROLE $psqldbadm WITH PASSWORD '$psqldbpassword';\"|psql"
		sleep 5
		sync
		echo "listen_addresses = '*'" >> /var/lib/pgsql/data/postgresql.conf
		echo "port = 5432" >> /var/lib/pgsql/data/postgresql.conf
		cat ./libs/pg_hba.conf > /var/lib/pgsql/data/pg_hba.conf
		echo "host all all 0.0.0.0/0 md5" >> /var/lib/pgsql/data/pg_hba.conf
		sed -r -i 's/^max_connections.*/max_connections\ =\ 1000/' /var/lib/pgsql/data/postgresql.conf
		service postgresql stop
		service postgresql start
		sleep 5
		sync
		echo "*:*:*:$psqldbadm:$psqldbpassword" > /root/.pgpass
		chmod 0600 /root/.pgpass
		iptables -A INPUT -p tcp -m multiport --dports $psqldbport -j ACCEPT
		service iptables save
		echo "PostgreSQL Installed"
		;;
	esac
fi

#
# Here, we verify if the software was properlly installed. If not, then we fail and make
# a full stop in the main installer.
#

if [ $dbinstall == "yes" ]
then
	case $dbflavor in
	"mysql")
		testmysql=`rpm -qi mariadb-server-galera|grep -ci "is not installed"`
		if [ $testmysql == "1" ]
		then
			echo ""
			echo "MariaDB Installation Failed. Aborting !"
			echo ""
			exit 0
		else
			date > /etc/openstack-control-script-config/db-installed
		fi
		;;
	"postgres")
		testpgsql=`rpm -qi postgresql-server|grep -ci "is not installed"`
		if [ $testpgsql == "1" ]
		then
			echo ""
			echo "PostgreSQL Installation Failed. Aborting !"
			echo ""
			exit 0
		else
			date > /etc/openstack-control-script-config/db-installed
		fi
		;;
	esac
fi

#
# The following two variables are used later in the database creation section
#

mysqlcommand="mysql --port=$mysqldbport --password=$mysqldbpassword --user=$mysqldbadm --host=$dbbackendhost"
psqlcommand="psql -U $psqldbadm --host $dbbackendhost -p $psqldbport"

#
# If we choose to create the databases (dbcreate=yes), then we proceed here to do it. Even if we choose not to
# install some modules, we proceed to create all possible databases for the OpenStack Cloud.
#

if [ $dbcreate == "yes" ]
then
	echo "Creating Databases"
	case $dbflavor in
	"mysql")
		echo "[client]" > /root/.my.cnf
		echo "user=$mysqldbadm" >> /root/.my.cnf
		echo "password=$mysqldbpassword" >> /root/.my.cnf
		echo "Keystone"
		echo "CREATE DATABASE $keystonedbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $keystonedbname.* TO '$keystonedbuser'@'%' IDENTIFIED BY '$keystonedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $keystonedbname.* TO '$keystonedbuser'@'localhost' IDENTIFIED BY '$keystonedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $keystonedbname.* TO '$keystonedbuser'@'$keystonehost' IDENTIFIED BY '$keystonedbpass';"|$mysqlcommand
		for extrahost in $extrakeystonehosts
		do
			echo "GRANT ALL ON $keystonedbname.* TO '$keystonedbuser'@'$extrahost' IDENTIFIED BY '$keystonedbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Glance"
		echo "CREATE DATABASE $glancedbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $glancedbname.* TO '$glancedbuser'@'%' IDENTIFIED BY '$glancedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $glancedbname.* TO '$glancedbuser'@'localhost' IDENTIFIED BY '$glancedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $glancedbname.* TO '$glancedbuser'@'$glancehost' IDENTIFIED BY '$glancedbpass';"|$mysqlcommand
		for extrahost in $extraglancehosts
		do
			echo "GRANT ALL ON $glancedbname.* TO '$glancedbuser'@'$extrahost' IDENTIFIED BY '$glancedbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Cinder"
		echo "CREATE DATABASE $cinderdbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $cinderdbname.* TO '$cinderdbuser'@'%' IDENTIFIED BY '$cinderdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $cinderdbname.* TO '$cinderdbuser'@'localhost' IDENTIFIED BY '$cinderdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $cinderdbname.* TO '$cinderdbuser'@'$cinderhost' IDENTIFIED BY '$cinderdbpass';"|$mysqlcommand
		for extrahost in $extracinderhosts
		do
			echo "GRANT ALL ON $cinderdbname.* TO '$cinderdbuser'@'$extrahost' IDENTIFIED BY '$cinderdbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Neutron"
		echo "CREATE DATABASE $neutrondbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $neutrondbname.* TO '$neutrondbuser'@'%' IDENTIFIED BY '$neutrondbpass';"|$mysqlcommand
		echo "GRANT ALL ON $neutrondbname.* TO '$neutrondbuser'@'localhost' IDENTIFIED BY '$neutrondbpass';"|$mysqlcommand
		echo "GRANT ALL ON $neutrondbname.* TO '$neutrondbuser'@'$neutronhost' IDENTIFIED BY '$neutrondbpass';"|$mysqlcommand
		for extrahost in $extraneutronhosts
		do
			echo "GRANT ALL ON $neutrondbname.* TO '$neutrondbuser'@'$extrahost' IDENTIFIED BY '$neutrondbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Nova"
		echo "CREATE DATABASE $novadbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $novadbname.* TO '$novadbuser'@'%' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $novadbname.* TO '$novadbuser'@'localhost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $novadbname.* TO '$novadbuser'@'$novahost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		for extrahost in $extranovahosts
		do
			echo "GRANT ALL ON $novadbname.* TO '$novadbuser'@'$extrahost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Nova-API:"
		echo "CREATE DATABASE $novaapidbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $novaapidbname.* TO '$novadbuser'@'%' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $novaapidbname.* TO '$novadbuser'@'localhost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $novaapidbname.* TO '$novadbuser'@'$novahost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		for extrahost in $extranovahosts
		do
			echo "GRANT ALL ON $novaapidbname.* TO '$novadbuser'@'$extrahost' IDENTIFIED BY '$novadbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Heat"
		echo "CREATE DATABASE $heatdbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $heatdbname.* TO '$heatdbuser'@'%' IDENTIFIED BY '$heatdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $heatdbname.* TO '$heatdbuser'@'localhost' IDENTIFIED BY '$heatdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $heatdbname.* TO '$heatdbuser'@'$heathost' IDENTIFIED BY '$heatdbpass';"|$mysqlcommand
		for extrahost in $extraheathosts
		do
			echo "GRANT ALL ON $heatdbname.* TO '$heatdbuser'@'$extrahost' IDENTIFIED BY '$heatdbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Horizon"
		echo "CREATE DATABASE $horizondbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $horizondbname.* TO '$horizondbuser'@'%' IDENTIFIED BY '$horizondbpass';"|$mysqlcommand
		echo "GRANT ALL ON $horizondbname.* TO '$horizondbuser'@'localhost' IDENTIFIED BY '$horizondbpass';"|$mysqlcommand
		echo "GRANT ALL ON $horizondbname.* TO '$horizondbuser'@'$horizonhost' IDENTIFIED BY '$horizondbpass';"|$mysqlcommand
		for extrahost in $extrahorizonhosts
		do
			echo "GRANT ALL ON $horizondbname.* TO '$horizondbuser'@'$extrahost' IDENTIFIED BY '$horizondbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Trove"
		echo "CREATE DATABASE $trovedbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $trovedbname.* TO '$trovedbuser'@'%' IDENTIFIED BY '$trovedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $trovedbname.* TO '$trovedbuser'@'localhost' IDENTIFIED BY '$trovedbpass';"|$mysqlcommand
		echo "GRANT ALL ON $trovedbname.* TO '$trovedbuser'@'$trovehost' IDENTIFIED BY '$trovedbpass';"|$mysqlcommand
		for extrahost in $extratrovehosts
		do
			echo "GRANT ALL ON $trovedbname.* TO '$trovedbuser'@'$extrahost' IDENTIFIED BY '$trovedbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Sahara"
		echo "CREATE DATABASE $saharadbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $saharadbname.* TO '$saharadbuser'@'%' IDENTIFIED BY '$saharadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $saharadbname.* TO '$saharadbuser'@'localhost' IDENTIFIED BY '$saharadbpass';"|$mysqlcommand
		echo "GRANT ALL ON $saharadbname.* TO '$saharadbuser'@'$saharahost' IDENTIFIED BY '$saharadbpass';"|$mysqlcommand
		for extrahost in $extrasaharahosts
		do
			echo "GRANT ALL ON $saharadbname.* TO '$saharadbuser'@'$extrahost' IDENTIFIED BY '$saharadbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Aodh"
		echo "CREATE DATABASE $aodhdbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $aodhdbname.* TO '$aodhdbuser'@'%' IDENTIFIED BY '$aodhdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $aodhdbname.* TO '$aodhdbuser'@'localhost' IDENTIFIED BY '$aodhdbpass';"|$mysqlcommand
		echo "GRANT ALL ON $aodhdbname.* TO '$aodhdbuser'@'$aodhhost' IDENTIFIED BY '$aodhdbpass';"|$mysqlcommand
		for extrahost in $extraaodhhosts
		do
			echo "GRANT ALL ON $aodhdbname.* TO '$aodhdbuser'@'$extrahost' IDENTIFIED BY '$aodhdbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo "Manila"
		echo "CREATE DATABASE $maniladbname default character set utf8;"|$mysqlcommand
		echo "GRANT ALL ON $maniladbname.* TO '$maniladbuser'@'%' IDENTIFIED BY '$maniladbpass';"|$mysqlcommand
		echo "GRANT ALL ON $maniladbname.* TO '$maniladbuser'@'localhost' IDENTIFIED BY '$maniladbpass';"|$mysqlcommand
		echo "GRANT ALL ON $maniladbname.* TO '$maniladbuser'@'$manilahost' IDENTIFIED BY '$maniladbpass';"|$mysqlcommand
		for extrahost in $extramanilahosts
		do
			echo "GRANT ALL ON $maniladbname.* TO '$maniladbuser'@'$extrahost' IDENTIFIED BY '$maniladbpass';"|$mysqlcommand
		done
		echo "FLUSH PRIVILEGES;"|$mysqlcommand
		sync
		sleep 5
		sync

		echo ""
		echo "Created Databases:"
		echo "show databases;"|$mysqlcommand
		
		checkdbcreation=`echo "show databases;"|$mysqlcommand|grep -ci $horizondbname`
		if [ $checkdbcreation == "0" ]
		then
			echo ""
			echo "DB Creation Failed. Aborting !!"
			echo ""
			rm -f /etc/openstack-control-script-config/db-installed
			exit 0
		else
			date > /etc/openstack-control-script-config/db-installed
		fi
		
		echo ""

		;;
	"postgres")
		echo "*:*:*:$psqldbadm:$psqldbpassword" > /root/.pgpass
		chmod 0600 /root/.pgpass
		echo "Keystone:"
		echo "CREATE user $keystonedbuser;"|$psqlcommand
		echo "ALTER user $keystonedbuser with password '$keystonedbpass'"|$psqlcommand
		echo "CREATE DATABASE $keystonedbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $keystonedbname TO $keystonedbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Glance:"
		echo "CREATE user $glancedbuser;"|$psqlcommand
		echo "ALTER user $glancedbuser with password '$glancedbpass'"|$psqlcommand
		echo "CREATE DATABASE $glancedbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $glancedbname TO $glancedbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Cinder:"
		echo "CREATE user $cinderdbuser;"|$psqlcommand
		echo "ALTER user $cinderdbuser with password '$cinderdbpass'"|$psqlcommand
		echo "CREATE DATABASE $cinderdbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $cinderdbname TO $cinderdbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Neutron:"
		echo "CREATE user $neutrondbuser;"|$psqlcommand
		echo "ALTER user $neutrondbuser with password '$neutrondbpass'"|$psqlcommand
		echo "CREATE DATABASE $neutrondbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $neutrondbname TO $neutrondbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Nova/Nova-API:" 
		echo "CREATE user $novadbuser;"|$psqlcommand
		echo "ALTER user $novadbuser with password '$novadbpass'"|$psqlcommand
		echo "CREATE DATABASE $novadbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $novadbname TO $novadbuser;"|$psqlcommand
		echo "CREATE DATABASE $novaapidbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $novaapidbname TO $novadbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Heat:" 
		echo "CREATE user $heatdbuser;"|$psqlcommand
		echo "ALTER user $heatdbuser with password '$heatdbpass'"|$psqlcommand
		echo "CREATE DATABASE $heatdbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $heatdbname TO $heatdbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Horizon:" 
		echo "CREATE user $horizondbuser;"|$psqlcommand
		echo "ALTER user $horizondbuser with password '$horizondbpass'"|$psqlcommand
		echo "CREATE DATABASE $horizondbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $horizondbname TO $horizondbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Trove:" 
		echo "CREATE user $trovedbuser;"|$psqlcommand
		echo "ALTER user $trovedbuser with password '$trovedbpass'"|$psqlcommand
		echo "CREATE DATABASE $trovedbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $trovedbname TO $trovedbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Sahara:"
		echo "CREATE user $saharadbuser;"|$psqlcommand
		echo "ALTER user $saharadbuser with password '$saharadbpass'"|$psqlcommand
		echo "CREATE DATABASE $saharadbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $saharadbname TO $saharadbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Aodh:"
		echo "CREATE user $aodhdbuser;"|$psqlcommand
		echo "ALTER user $aodhdbuser with password '$aodhdbpass'"|$psqlcommand
		echo "CREATE DATABASE $aodhdbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $aodhdbname TO $aodhdbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo "Manila:"
		echo "CREATE user $maniladbuser;"|$psqlcommand
		echo "ALTER user $maniladbuser with password '$maniladbpass'"|$psqlcommand
		echo "CREATE DATABASE $maniladbname"|$psqlcommand
		echo "GRANT ALL PRIVILEGES ON database $maniladbname TO $maniladbuser;"|$psqlcommand
		sync
		sleep 5
		sync

		echo ""
		echo "Created Databases:"
		echo "\list"|$psqlcommand

		checkdbcreation=`echo "\list"|$psqlcommand|grep -ci $horizondbname`
		if [ $checkdbcreation == "0" ]
		then
			echo ""
			echo "DB Creation Failed. Aborting !!"
			echo ""
			rm -f /etc/openstack-control-script-config/db-installed
			exit 0
		else
			date > /etc/openstack-control-script-config/db-installed
		fi

		echo ""
		;;
	esac
fi

echo ""
echo "Database Process DONE !!"
echo ""
