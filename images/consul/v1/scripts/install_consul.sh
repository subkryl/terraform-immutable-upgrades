#!/bin/bash

set -x
set -e

echo "Fetching Consul..."
cd /tmp
wget https://releases.hashicorp.com/consul/0.6.2/consul_0.6.2_linux_amd64.zip -O consul.zip

echo "Installing Consul..."
unzip consul.zip >/dev/null
chown root:root consul
chmod +x consul
mv consul /usr/local/bin/consul
mkdir -p /etc/consul.d
mkdir -p /mnt/consul
mkdir -p /etc/service

rm -f consul.zip
