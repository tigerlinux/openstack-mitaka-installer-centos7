DNS-BASED HOSTNAME AUTOCONFIG SCRIPT
For VM's running: Centos 5, Centos 6, Centos 7, Debian 6, Debian 7, Debian 8 and Ubuntu Server 14.04lts
Reynaldo R. Martinez P.
TigerLinux@gmail.com

This script can be used to auto-configure the hostname of the virtual machine, provided that the
DNS service has the reverse records (in-addr.arpa ptr's) correctly configured with the hostnames.

Usage.

Copy the "script-autoconfig-server.sh" to /usr/local/bin and make it executable (mode 755 will do).
Copy the config file autoconfig-server-options.conf to /etc/ and make it mode 644.

chmod 755 /usr/local/bin/script-autoconfig-server.sh
chmod 644 /etc/autoconfig-server-options.conf


Include the script in your rc.local if you want it to run in every boot.

Sample line in your /etc/rc.local:

/usr/local/bin/script-autoconfig-server.sh > /var/log/script-autoconf-server-last-run.log

NOTE: ENSURE YOU HAVE the "host" utility installed, or the script will fail.

This script has been tested on:

Centos 5
Centos 6
Centos 7
Debian 6
Debian 7
Debian 8
Ubuntu Server 14.04lts


END.-
