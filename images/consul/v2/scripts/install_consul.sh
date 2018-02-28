#!/bin/bash

set -x
set -e

echo "Fetching Consul..."
cd /tmp
wget https://releases.hashicorp.com/consul/1.0.5/consul_1.0.5_linux_amd64.zip -O consul.zip

echo "Installing Consul..."
unzip consul.zip >/dev/null
chown root:root consul
chmod +x consul
mv consul /usr/local/bin/consul
mkdir -p /etc/consul.d
mkdir -p /mnt/consul
mkdir -p /etc/service

rm -f consul.zip
