#!/bin/bash

set -e

CONSUL_CONFIG_FILE="/etc/consul.d/config.json"

MY_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
MY_PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)

REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | sed 's/  "region" : "\(.*\)",\?/\1/')

VPC=$(aws ec2 describe-instances --region ${REGION} --instance ${MY_INSTANCE_ID} --query 'Reservations[0].Instances[0].VpcId' --output text)

CONSUL_SERVERS=$(aws ec2 describe-instances --region us-east-1 --filters "Name=vpc-id,Values=${VPC}" "Name=tag:consul-type,Values=server" --query 'Reservations[].Instances[].PrivateIpAddress' --output text)
CONSUL_SERVERS_JSON=$(jq -n -c -M --arg s "${CONSUL_SERVERS}" '($s|split("\\s+"; "" ))')

CONSUL_TYPE=$(aws ec2 describe-instances --region ${REGION} --instance ${MY_INSTANCE_ID} --query 'Reservations[0].Instances[0].Tags[?Key==`consul-type`].Value' --output text)

if [ ${CONSUL_TYPE} == "server" ]; then
        cat <<EOF > ${CONSUL_CONFIG_FILE}
{
	"bind_addr": "${MY_PRIVATE_IP}",
        "server": true,
        "bootstrap_expect": 3,
        "retry_join": ${CONSUL_SERVERS_JSON},
        "skip_leave_on_interrupt": true
}
EOF
else
        cat <<EOF > ${CONSUL_CONFIG_FILE}
{
	"bind_addr": "${MY_PRIVATE_IP}",
        "retry_join": ${CONSUL_SERVERS_JSON}
}
EOF
fi
