#!/bin/bash

set -x
set -e

cat << 'EOF' > /etc/dhcp/dhclient-enter-hooks
make_resolv_conf() {
	RESOLV_CONF_DHCP=/etc/resolv.conf.dhcp
	> ${RESOLV_CONF_DHCP}

	if [ -n "${new_domain_name_servers}" ]; then
		for nameserver in ${new_domain_name_servers} ; do
			echo "nameserver ${nameserver}" >> "/etc/resolv.conf.dhcp"
		done
	fi
}
EOF

echo "server=/consul/127.0.0.1#8600" > /etc/dnsmasq.d/10-consul
# TODO retrieve/calculate this?
echo "resolv-file=/etc/resolv.conf.dhcp" > /etc/dnsmasq.d/0-default

systemctl enable dnsmasq
