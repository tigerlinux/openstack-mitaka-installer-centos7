# Unattended Installer (Semi Automated) for OpenStack (MITAKA)
Reynaldo R. Martínez P.
E-Mail: TigerLinux at Gmail dot com
Caracas, Venezuela.

## Introduction

This installer was made to automate the tasks of creating a virtualization infrastructure based on OpenStack. So far, There are 3 "flavors" for this installer: One for  Centos 7, one for Ubuntu 14.04 LTS and one for Ubuntu 16.04 LTS.

All two versions produce a fully production-usable OpenStack. You can use this installer to make a single-node all-in-one OpenStack server, or a more complex design with controller and compute nodes.

In summary, this installer can produce an OpenStack virtualization service completely usable in production environments, however, remember that the "bugs" factor don't depend solely on us. From time to time OpenStack packages can bring us some bugs too. We are using rpm/deb packages from Ubuntu and Redhat repositories and they can have their own bugs. 

## Using the Installer.

### First

* READ, READ, READ and after some rest, READ AGAIN!. *

Read everything you can from * OpenStack * if you want to venture into the virtualization in the cloud World. If you do not like reading, then support yourself on someone who can do the reading. Please do not try to use this Installer without having any knowledge at hand. View file `NOTES.txt` to understand a little more about the knowledge which you should have.

You can begin here: * http://docs.openstack.org *

The big world of * OpenStack * includes several technologies from the world of Open-source and the world of networks that must be understood thoroughly before even attempting any installation of OpenStack, whether you use this installation tool or any other. In short, if you do not have the knowledge, do not even try. Gain the knowledge first, then proceed.

Before using the installer, you must prepare your server of servers. Again, in the file `NOTES.txt` you will find important points that you should understand before start an installation using this tool. The installer will make some validations, should yield negative results, will abort the process.

### Second: Edit the installer main configuration file.

First thing to do: Copy the "main-config.rc" file from "sample-config" directory to "configs" directory. Without the file "main-config.rc" in the proper directory (configs), the installer will not work.

The installer has a central configuration file: `./configs/main-config.rc`. This file is well documented so * if you did your homework and studied * about * OpenStack *, you will know what to change there. There are very obvious things like passwords, IP addresses, modules to install and dns domains or domain names.

In the version by default, the configuration file has selections modules to install what is known as an "all-in-one" (an OpenStack monolithic service with controller-compute capabilites). You can just change the IP with the one assigned to your server (please DO NOT use * localhost * and DO NOT use a Dynamic DHCP assigned IP).

Additionally, there are some modules that are in default "no":

* Ceilometer *
* Heat *
* Swift *
* Trove * 
* Sahara *
* SNMP *

We recommend to activate swift install option "only If you are really going to use it". * Swift * alone is almost as extensive as OpenStack. Use if you REALLY know what you're doing and if you are REALLY going to use it. Remember the functions of all OpenStack modules:

* Keystone: Identity Service *
* Glance: Image Service *
* Cinder: Block Storage Service *
* Swift: Object Storage Service *
* Neutron: Networking Service *
* Nova: Compute Service *
* Ceilometer: Metrics/Telemetry Service *
* Aodh (installed along ceilometer): Alarming Service (needed if you want to create autoscaling groups with Heat Cloudformation) *
* Heat: Orquestration/Cloudformation Service *
* Trove: Database Service (DBaaS) *
* Sahara: Data Processing Service (Big Data) *

The SNMP module installs monitoring variables useful if you want to monitor OpenStack with SNMP but does not install any monitoring application. The variables are described (if you install the support) in `/etc/snmp/snmpd.conf`.

NOTE: Files for ZABBIX agent in the "Goodies" directory are also included.

If you want to install an "all-in-one" openstack service, only change passwords, IP addresses and mail domains and *dhcp/dnsmasq* info appearing in the configuration file.

After updating the configuration file, run at the root of directory script the following command:

```
# ./main-installer.sh install
```

The installer asks if you want to proceed (y/n).

If you run the installer with the additional parameter * auto *, it will run automatically without asking you confirmation. Example:

```
# ./main-installer.sh install auto
```

You can save all outputs produced by the installer using the tool `tee`. Example:

```bash
./main-installer.sh install | tee -a /var/log/my_log_de_install.log
```

## Controlling the installer behavior

As mentioned before, you can use this installer for more complex designs. Example:

* A single all-in-one monolithic server *
* A cloud with a controller-compute and several compute nodes *
* A cloud with a pure controller and several compute nodes *

### Controller node:

If your controller node will include a compute service (controller + compute, or an all-in-one server), the following variable in the configuration file must be set to “no”:

```bash
nova_without_compute="no"
```

If you use ceilometer in the controller, and likewise the controller includes compute service, the following variable must also be set to "no":

```bash
ceilometer_without_compute="no"
```

However, if you are installing a "pure" controller (without compute service) set the following variables to "yes":

```bash
nova_without_compute="yes"
ceilometer_without_compute="yes"
```

### Compute nodes:

For the compute nodes, you must set to "yes" (this is mandatory) the installation variables for Nova and Neutron modules. The remaining modules (glance, cinder, horizon, trove, sahara and heat) must be set to "no". If you are using Ceilometer in the controller, you also must set it's installation variable to “yes” along with the ones for Nova and Neutron. In Addition, the following variables in sections of nova and neutron must be set to "yes":

```bash
nova_in_compute_node="yes"
neutron_in_compute_node="yes"
```

And if you are using ceilometer also the following variable must be "yes" for compute nodes:

```bash
ceilometer_in_compute_node="yes"
```

You must place the IP's for the services running in the controller (neutron, keystone, glance and cinder) and the Ip's for the Database and message broker backends. This is valid for either a controller or a compute:

```bash
novahost="Controller IP Address"
glancehost="Controller IP Address"
cinderhost="Controller IP Address"
neutronhost="Controller IP Address"
keystonehost="Controller IP Address"
messagebrokerhost="Message Broker IP Address"
dbbackendhost="Database Server IP Address"
vncserver_controller_address | spiceserver_controller_address = "Controller IP Address"
```

If you use ceilometer, the same case applies:

```bash
ceilometerhost = "Controller IP Address"
```

For compute nodes, you must place the following variables with the IP in the compute node:

```bash
neutron_computehost = "Compute Host IP Address"
nova_computehost = "Compute Host IP Address "
```

### Database Backend

The installer has the ability to install and configure the database service, and also it will create all the databases. This is completely controllable by the configuration file through the following variables:

```bash
dbcreate = "yes"
dbinstall = "yes"
dbpopulate = "yes"
```

With these three options set to "yes", the database software is installed, will be configured and databases will be created using all the information contained in the configuration file.

> ** WARNING **: If you choose these options, you must ensure that there is
> NO database software previously installed or the process will fail.

In our installation tool, you can choose to install and/or use between MySQL-based and PostgreSQL-based engines. For the MySQL-Based we really use MariaBD (if the installer installs the database engine and mysql is selected as backend). Please note that along openstack release history, some "strange things" had happened when postgresql is used as database backend. We really recommend using MariaDB (MySQL-Based) database backends in OpenStack production environments. At the end is up to you what backend to use, but be warned: If something gets broken with postgresql, it's not our fault !.

If you prefer to “not install” any database software because you already have one installed somewhere else (a database farm), and also have the proper administrative access to the database engine, set the variables as follows:

```bash
dbcreate = "yes"
dbinstall = "no"
dbpopulate = "yes"
```

With this, the database software will not be installed, but it's up to you (or your * DBA *) to ensure you have full administrative access to create and modify databases in the selected backend.

If you do not want to install database software nor create databases (we assume that you already have previously created then in a farm or a separate server or even manually in the controller) set the three values "no":

```bash
dbcreate = "no"
dbinstall = "no"
dbpopulate = "no"
```

In any case, always remember to properly set the database-control variables inside the installer configuration file.


### RPC Messaging backend (Message Broker)

As part of the components to install and configure, the installer installs and configure the software for * AMQP * (the * Message Broker *). This step * IS * mandatory for a controller or * all-in-one * OpenStack server. If your server or servers have a message broker already installed, conflicts can occur that prevent the correct operation of the installation.

Again, the installer configuration file will control which AMPQ service to install and configure. In earlier releases (up to Liberty) we provided two options for AMPQ: RabbitMQ and Qpid. From Mitaka, we are allowing only RabbitMQ. In the practice, this is by far the best and most recommended option for OpenStack.


### Console Manager (NOVNC / SPICEHTML5)

Through a configurable option in the installer configuration file (consoleflavor), you can choose between NoVNC and SpiceHTML5. If you want to eventually use SSL for the Dashboard, please leave the default (novnc) as it easier to configure with SSL.


### Cloudformation and AutoScaling

If you want to use Cloudformatio with AutoScaling, you MUST install both "heat" and "ceilometer". Also you need to include ceilometer alarming:

```bash
heatinstall=yes
ceilometerinstall=yes
ceilometeralarms="yes"
```

NOTE: From "OpenStack Release 13", ceilometer alarms is controlled by "aodh" module. This installer install and configure aodh along ceilometer components from inside ceilometer installation module.


### Trove

If you choose to install trove, this installation tool will install and configure all the software needed, but IT WILL NOT configure trove-ready images. That's part of your tasks as a Cloud Administrator. Please follow recomendations from the community regarding proper-configured glance images for trove. The "very big secret" of proper trove deployment is the glance-image. Fail to do that properlly, and forget about trove working
the way it should.

Tips for a properlly working trove image:

- Cloud init must be installed on the image and configured for start at boot time. Please eliminate "mounts" from /etc/cloud/cloud.cfg or your vm
  will try to auto-mount the ephemeral disk. This can interfere with trove guest agent activities.
- The trove guest agent MUST BE installed and configured in the image. Also, give sudo root-powers to the "trove" account on the glance image. The
  guest agent perform some changes in the vm that requires root access. The trove guest agent (if installed from ubuntu/centos repositories) uses
  a "trove" account to run.
- Install the database engine software in the glance image too. Trove guest agent can do this for you in many ways too.
- TRICK: You can install the guest agent, configure it, create the "sudo" permissions, and install the database software vía Cloud init. You just
  need to create a file /etc/trove/cloudinit/DATASTORE-NAME.cloudinit (sample: /etc/trove/cloudinit/mysql.cloudinit) with the commands needed to
  do everything. This file can be any script-based languaje (sh, bash, etc.).
- Flavors: If you plan to use locally-based storage for trove (instead of cinder-based), remember to choose a flavor for your database services
  that contains an ephemeral disk. Trove requires an extra disk for the database.


### Manila

If you choose to install manila, this installation tool will install and configure all the software needed, and also, it will configure the LVM based backend, if you choose to use that backend. As a requirement, the LVM backend need a previouslly configured LVM group (same case as Cinder using LVM). By default, our main config names this volume group "manila-volumes" but yoy can change it in the config. Remember to create the LV if you plan to include Manila with LVM backed storage:

```bash
pvcreate /dev/sde
vgcreate manila-volumes /dev/sde
```

Another example with an free /dev/sde3 partition:

```bash
pvcreate /dev/sde3
vgcreate cinder-volumes /dev/sde3
```


### Designate

EXPERIMENTAL: We are including "experimental support" for Designate (DNS as a Service) in our installer. By the moment we are only using BIND 9 backend. Our designate module install everything you need to fully operate designate with a BIND 9 backend and software installed in the server, and even gives you the option of integrate designate with nova and neutron for automatic record creation for floating IP's and Fixed IP's. If you read designate documentation, you can add other BIND 9 servers and control them with designate OpenStack service. Remember: This is still experimental.

More information about designate:

http://docs.openstack.org/releasenotes/designate/mitaka.html
http://docs.openstack.org/developer/designate/



### Support Scripts installed with this solution

This installer will place a OpenStack Services control script in the “/usr/local/bin” path:

```bash
openstack-control.sh OPTION
```

The script uses the following options:

1. **enable**: Enables the services to start at boot time.
2. **disable**: disable services start at boot time.
3. **start**: starts all services.
4. **stop**: stops all services.
5. **restart**: restart all services.
6. **status**: displays the status of all services.

NOTE: We used or best judgment to ensure the proper start/stop order in the openstack-control.sh script. That being said, you could benefit a lot by using this script to control you cloud instead of the order normally set by “init”, “systemctl” or “upstart”. A good choice can be to place the script inside rc.local file. Your choice.

**IMPORTANT NOTE**: Again, We recommend using the openstack-control.sh script to initialize all OpenStack services!. Put all openstack services in "disable" state with "openstack-control.sh disable" and call the script with the "start" option from inside the /etc/rc.local file:

```bash
/usr/local/bin/openstack-control.sh start
```

This script is included by the installer in every single OpenStack node (controller and compute nodes)

You can also control individual OpenStack modules with the script:

```bash
/usr/local/bin/openstack-control.sh OPTION MODULE
```

Samples:

```bash
/usr/local/bin/openstack-control.sh start nova
```

```bash
/usr/local/bin/openstack-control.sh restart neutron
```

```bash
/usr/local/bin/openstack-control.sh status cinder
```

By the moment, we support the following modules:
- keystone
- swift
- glance
- cinder
- neutron
- nova
- ceilometer
- heat
- sahara

NOTE: aodh (Ceilometer Alarming) is managed inside "ceilometer" option, so if you call "openstack-control.sh ACTION ceilometer", the "ACTION" (stop/start/enable/disable/etc) will be applied to both ceilometer and aodh services.

Soon, we'll include other modules. By the moment our priorities are focused in manila, designate and murano.



```bash
openstack-log-cleaner.sh
```

The installer will place a script “openstack-log-cleaner.sh” in the path “/usr/local/bin” that have the ability to “clean” all OpenStack related logs.

This script is called during the final phase of installation to clean all logs before leaving the server installed and running for the very first time, but can also be used by you “Cloud Administrator” to clean all OpenStack related logs whenever you consider it necessary.

```bash
compute-and-instances-full-report.sh
```

This script is also copied by the installer onto /usr/local/bin directory. The function of this script is give a report of all compute nodes in the openstack cloud and it's related virtual machines (instances) including the IP or IP's assigned to the instances.


### Keystone Environment Admin Variables

This installer will place the following files in your OpenStack Nodes:

```bash
/root/keystonerc_admin
/root/keystonerc_fulladmin
```

This files include your "admin" credentials (user/password included) along the URL endpoints for Keystone Service. The file first file use the normal public endpoint at port tcp 5000. The second one, uses the full admin port 35357.

Sourcing the *keystonerc_admin* file in your environment will allow you to perform normal administration tasks, not included the ones related to keystone advanced tasks. Sourcing the *keystonerc_fulladmin* file in your environment will give you "super cow god-like powers" over your cloud installation.

Then:

Normal admin tasks:

```bash
source /root/keystonerc_admin
```

Super-cow god-like powers:

```bash
source /root/keystonerc_fulladmin
```


### STARTING VIRTUAL MACHINES AVOIDING I/O STORMS

If you suffer a total blackout and your cloud service goes completely down, and then try to start it including all virtual machines (instances), chances are that you will suffer a I/O storm. That can easily collapses all your servers or at least slow them down for a while.

We include a script called “openstack-vm-boot-start.sh” that you can use to start all your OpenStack VM's (instances) with a little timeout between each virtual machine. You need to include the name or UUID of the instances that you want to start automatically in the following file:

```bash
/etc/openstack-control-script-config/nova-start-vms.conf
```

Place the script in the rc.local file ONLY in the controller node.

NOTE: The names of the VMs must be obtained from "nova list" command.


### DNSMASQ

Neutron dhcp-agent uses **DNSMASQ** for IP assignation to the VM's (instances). We include a customized dnsmasq-control file with some samples that you can use to fine-tune your dhcp-agent:

```
/etc/dnsmasq-neutron.d/neutron-dnsmasq-extra.conf
```

There are commented examples in the file. Use these examples to pass options to
different instances of dnsmasq created for each subnet where you select the option to use * dhcp *.

Recommendation: Try to have a good **DNS** structure for your cloud.


### Installer modularization

While the main setup process "* main-installer.sh *" is responsible for calling each module of each installer component, these modules are really independent of one another, to the point that they can be called sequentially and manually by you. Is not the common case, but can be done. The normal order of execution for each module is as follows (assuming that all components will be installed):

* requeriments.sh
* messagebrokerinstall.sh
* databaseinstall.sh
* requeriments-extras.sh (only present for Ubuntu based installations)
* keystoneinstall.sh
* swiftinstall.sh
* glanceinstall.sh
* cinderinstall.sh
* neutroninstall.sh
* novainstall.sh
* ceilometerinstall.sh
* heatinstall.sh
* troveinstall.sh
* saharainstall.sh
* snmpinstall.sh
* horizoninstall.sh
* postinstall.sh


Then again, we do not recommend to run those modules out of the main installer, unless of course you know exactly what are you doing.


### RECOMMENDATIONS FOR INSTALLATION IN CENTOS AND UBUNTU SERVER.

#### Centos 7:

1. Install Centos with the selection of packages for "Infrastructure Server". Make sure you have properly installed and configured both SSH and NTP. Ntpdate is also recommended. Again, a proper DNS infrastructure is very recommended.

2. Add the EPEL and RDO repositories (see "NOTES.txt").

3. Install and configure OpenVSWitch (again, see "NOTES.txt").

*WARNING*: OpenStack does not support MySQL lower than 5.5. See notes and take proper steps. If you use our installation tool in order to install database support, we will install MariaDB 5.5.x directly obtained from RDO repositories.

IMPORTANT NOTE: The installer disables Centos 7 SELINUX. We had found some bugs, specially when using PostgreSQL and with some scenarios with NOVA-API.

#### Ubuntu 14.04 LTS / 16.04 LTS:

1. Install Ubuntu Server 14.04/16.04 LTS standard way and select as an additional package "OpenSSH Server". Install and configure the ntpd service. Also SSH. It is also recommended to use ntpdate.

2. Install and configure OpenVSWitch (see "NOTES.txt").

As you can see in all cases, NTP and SSH are very important. Fail to configure those services correctly, and prepare to have a live full of misery.


### What about Debian ?:

We supported debian meanwhile it was proper documentation available for this distro on docs.opentstack.org. We tried to include it again in Liberty, but after some research found most "real world" OpenStack deployments are using Ubuntu server as first option and Centos as second option with other distros lagging way behind ubuntu and centos. This convinced us about the futility of continuing any work on a Debian based OpenStack installer... at least for now.

If in the future "docs.openstack.org" include any usable documentation for debian, we'll consider it again, but meanwhile, debian won't be an option for us.


### Cinder:

If you are using CINDER with lvm-iscsi, be sure to have a free partition or disk to create a LVM called "cinder-volumes". Example (free disk /dev/sdc):

```bash
pvcreate /dev/sdc
vgcreate cinder-volumes /dev/sdc
```

Another example with an free /dev/sda3 partition:

```bash
pvcreate /dev/sda3
vgcreate cinder-volumes /dev/sda3
```

NOTE: If you plan to use Cinder just for learning/lab purposes, you always can create a "loop device based" disc. It's completelly up to you.

Our installer also can automate Cinder configuration for NFS and GlusterFS backends. See the main-config.rc file for more information.


### Swift:

If you are going to use swift, remember to have the disk/partition to be used for swift mounted on a specific directory that also should be indicated in the Installer main configuration file (main-config.rc).

example:

Variable `swiftdevice ="d1"`

In the fstab "d1" must be mounted as follows:

```
/dev/sdc1 /srv/node/d1 ext4 acl,user_xattr 0 0
```

In this example, we assume that there is an already formatted "/dev/sdc1" partition. You MUST use a file system capable of ACL and USER_XATTR. That being said, we recommend EXT4 or XFS or similar file systems.

NOTE: If you plan to use Swift just for learning/lab purposes, you always can create a "loop device based" disc. It's completelly up to you.


### Architecture:

Whether you use Centos or Ubuntu, you must choose to use 64 bits (amd64 / x86_64). Do not try to install OpenStack in 32 bits. Repeat with us: "I will never ever try to install OpenStack on 32 bits O/S".


### NTP Service:

We cannot stress enough so VITAL it is to have all the servers in the OpenStack cloud properly time synchronized. Read the documentation of OpenStack to know more about it, but if you are an I.T. professional, you should know how important it is to have all your datacenter equipment properlly ntp-synchronized, specially, cluster services.


### Recommendations for Virtualbox.

You can use this installer inside a VirtualBox VM if you want to use it to practice and learn OpenStack. The VirtualBox VM should have a "minimum" of 1GB's of RAM but for better results try to ensure 2GB's of RAM for the VM. A 4 GB's RAM VM is better if you want to include services like swift or trove. A full-service all-in-one OpenStack could require more. 8 GB's RAM based VirtualBox VM is a more "realistic" mini-lab if you want to explore OpenStack without having to dedicate a real server.


### Hardware recommendations for a VirtualBox VM:

Hard disks: one for the operating system (16 GB minimum's), one for Cinder-Volumes and another for swift. At least 8GB's for each disk (SWITF and cinder-volumes). 
Network: three interfaces:
Interface 1 in NAT mode for Internet Access.
Interface 2 in "only host adapter” mode, “PROMISC option: all". Suggestion: Use vboxnet0 with the network 192.168.56.0/24 (disable dhcp at virtualbox) and assign the IP 192.168.56.2 to the interface (the IP 192.168.56.1 will be on the real machine).
Interface 3 in "only host adapter” mode, “PROMISC option: all". Suggestion: Use vboxnet1 with the network 192.168.57.0/24 (disable dhcp at virtualbox). This will be assigned to the VM's network inside OpenStack in the eth2 interface and IP range 192.168.57.0/24 (the IP 192.168.57.1 will be in the real machine).

Make the O/S installation using the first disk only (the second and third ones will be used for cinder-volumes and swift). Add the openstack repositories (remember to see **NOTES.txt**), make the proper changes inside the installer configuration file, create the cinder volume as follows:


```bash
pvcreate /dev/sdb
vgcreate cinder-volumes /dev/sdb
```

If you are using swift, create the partition on the third disk (/dev/sdc1) and mount it according to the notes in this document.

Make the installation indicating that the bridge Mapping (within main-config.rc) is:

```bash
bridge_mappings = "public: br-eth2"
```

Copy the `main-config.rc` file from the sample-config directory to config directory.

Change IP in the `main-config.rc` to the IP assigned to the VM inside the network 192.168.56.0/24 (sample: 192.168.56.2).

Run the installer.

enjoy:-)

You can enter the web server via the interface 192.168.56.x for
run OpenStack management tasks. Create the subnet in the range
of eth2 (192.168.57.0/24) and may enter the VM's OpenStack from
real machine that will interface 192.168.57.1.

From outside VirtualBox you can enter to the Horizon web Interface by using the vboxnet0 assigned IP (192.168.56.2) and to the OpenStack VM instances running inside vboxnet1 network (192.168.57.0/24).


### Uninstalling

The main script also has a parameter used to completely uninstall OpenStack:

```
# ./main-installer.sh uninstall
```
or

```
# ./main-installer.sh uninstall auto
```

The first way to call the uninstall process asks you "y/n" for continue or abort, but if you called the script with the extra "auto" setting, it will run without asking anything from you and basically will erase all that it previously installed.

It is important to note that if the dbinstall="yes" option is used inside the installer configuration file, the uninstaller will remove not only the database engine but also all created databases.

If you DON'T WANT TO REMOVE the databases created before, modify the "main-config.rc" and set the dbinstall option to “no”. This will make the preserve the databases.

WARNING: If you are not careful, could end up removing databases and losing anything that you would like to backup. Consider yourself warned!.

This is very convenient for a reinstall. If for some reason your OpenStack installation needs to be rebuilt without touching your databses, uninstall using dbinstall = "no" and when you are going to reinstall, place all database options in "no" to preserve both the engine and all its created databases:

```
dbcreate = "no"
dbinstall = "no"
dbpopulate = "no"
```

If your system has multiple nodes (controller / compute) use the
`main-config.rc` originally used to install each node in order to uninstall it.


### Goodies

In the * Goodies * directory you will find some scripts (each with their respective readme). You can use with those scripts as you see fit with your OpenStack installation. View the scripts and their respective "readme files" to better understand how to use them!.


### END.-
