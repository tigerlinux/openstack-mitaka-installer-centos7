#!/bin/bash
#
# Unattended installer for OpenStack.
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
#
# Script for Metadata Provisioning
# Only to be executed inside the Instances
#
# Include this script inside your VM's rc.local file
#
#

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

#
#
# We define some variables
#
metadatadrivelabel="config-2"
metadatadrivemount="/mnt/config-2"
metadatafile="/mnt/config-2/openstack/latest/meta_data.json"
metadatatext="/var/tmp/lattest-metadata.txt"
runoncecontrolfile="/etc/metadata-provision-already-ran.conf"

#
# This script should run only one time. The following control file
# ensures we only run once.
#

if [ -f $runoncecontrolfile ]
then
	echo ""
	echo "This script was already executed"
	echo ""
	exit 0
fi


#
# We create metadata directory
#

mkdir -p $metadatadrivemount > /dev/null 2>&1

#
# Then we try to mount metadata drive offered by openstack
#

mount LABEL=$metadatadrivelabel $metadatadrivemount > /dev/null 2>&1

#
# We verify the existence of metadata file. If it cant be accesed, we just aborts
#

if [ -f $metadatafile ]
then
	echo ""
	echo "Extrayendo metadata desde archivo $metadatafile"
	cat $metadatafile |sed -e 's/[{}]/''/g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' > $metadatatext
else
	echo ""
	echo "Metadata file unavailable. Aborting !!."
	echo ""
	exit 0
fi

#
# If we could obtain the metadata file, we try to parse it
#

adminpass=`grep "admin_pass" $metadatatext|cut -d: -f2|cut -d\" -f2`
passexist=`grep "admin_pass" $metadatatext|cut -d: -f2|cut -d\" -f2|wc -l`
sshrootkey=`grep "public_keys" $metadatatext|cut -d: -f3|cut -d\" -f2`
keyexist=`grep "public_keys" $metadatatext|cut -d: -f3|cut -d\" -f2 |wc -l`

if [ $passexist == 1 ]
then
	echo ""
	echo "Provisioning admin password from metadata"
	echo "root:$adminpass"|chpasswd
	echo "Done !"
	echo ""
else
	echo ""
	echo "Admin password unavailable"
	echo ""
fi

if [ $keyexist == 1 ]
then
	echo ""
	echo "Provisioning SSH key from metadata"
	mkdir -p /root/.ssh > /dev/null 2>&1
	echo "$sshrootkey" >> /root/.ssh/authorized_keys
	chmod 0440 /root/.ssh/authorized_keys
	echo ""
else
	echo ""
	echo "SSH Key unavailable"
	echo ""
fi

#
# All ready, then we create the control file so this scripts does not run again
#
echo "THE WORLD IS TWISTED BUT ALL IS OK !!" > $runoncecontrolfile
#

#
# Basic cleanup
#

cd /
umount $metadatadrivemount > /dev/null 2>&1
rmdir $metadatadrivemount

#
#

echo ""
echo "My task is done"
echo ""
