Unattended installer for OpenStack.
Reynaldo R. Martinez P.
E-Mail: TigerLinux@Gmail.com

SSH/ADMIN PASSWORD METADATA-BASED SCRIPT AUTOCONFIGURATOR

This script is intended solely to automate the inclusion of SSH root key and
password provided they have been defined in the metadata of a virtual machine
when you create it on OpenStack.

The script will mount the config-drive (if available), will read the administrative
password for root and its SSH key (if available) and will provision both the 
password and the SSH key on the virtual machine.

IMPORTANT NOTE: If an administrative password is not placed in the definition
of the virtual machine, OpenStack will generate a random one.

Usage: 

Place "metadata-provision.sh" script into /usr/local/bin directory and made it
executable (chmod 755 /usr/local/bin/metadata-provision.sh)

Include the script in the /etc/rc.local file inside the virtual machine. Example:

/usr/local/bin/metadata-provision.sh > /var/log/metadata-provision-script.log

END.-
