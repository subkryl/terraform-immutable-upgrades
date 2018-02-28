#!/bin/bash

set -x
set -e

# Add PEERDNS=no to ifcfg-eth0 since we don't want the dhcp client to rewrite /etc/resolv.conf
# echo "PEERDNS=no" >> /etc/sysconfig/network-scripts/ifcfg-eth0

cat <<EOF > /etc/resolv.conf
search ec2.internal
nameserver 127.0.0.1
EOF
