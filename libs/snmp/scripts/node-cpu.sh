#!/bin/bash
#
#
# Unattended installer for OpenStack.
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Variable 1: % CPU "user"
# Variable 2: % CPU "system"
# Variable 3: % CPU "idle"
# Variable 4: % CPU "waiting-for-I/O"
# 

PATH=$PATH:/bin:/sbin:/usr/bin:/usr/sbin:/usr/local/bin:/usr/local/sbin

mystats=`mpstat 1 4 |grep -i "Average:"`

usercpu=`echo $mystats|awk '{print $3}'`
systemcpu=`echo $mystats|awk '{print $5}'`
idlecpu=`echo $mystats|awk '{print $11}'`
wiocpu=`echo $mystats|awk '{print $6}'`


echo $usercpu
echo $systemcpu
echo $idlecpu
echo $wiocpu
