#!/bin/bash
#
# Unattended installer for OpenStack.
# Reynaldo R. Martinez P.
# E-Mail: TigerLinux@Gmail.com
#
# Variable 1: Disk usage (bytes) - Nova Instances
# Variable 2: Disk usage (bytes) - Glance Images
#


PATH=$PATH:/bin:/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin

du -c --block-size=1 /var/lib/nova/instances/|tail -n 1|awk '{print $1}'
du -c --block-size=1 /var/lib/glance/images/|tail -n 1|awk '{print $1}'
