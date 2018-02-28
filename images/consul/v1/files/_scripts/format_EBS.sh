#!/bin/bash
set -e

DEVICE="/dev/xvdb"
logFile="/var/log/$(basename ${0}).log"

function error() {
    DATE=`date '+%Y-%m-%d %H:%M:%S'`
    if [[ -z "$logFile" ]]; then echo "$DATE -- $1" >> $logFile; fi
    echo $1
    exit 1
}

MY_INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | grep region | sed 's/  "region" : "\(.*\)",\?/\1/')

# 60 seconds / 12 attempts
cnt=12
while [[ ! -b /dev/xvdb ]] && [[ "$cnt" -gt 0 ]] ; do
    cnt=$(($cnt-1))
    sleep 5
done

[[ -b "$DEVICE" ]] || error "$DEVICE not available"

# cnt=12
# while [[ -z "$STATUS" || "$STATUS" != "attached" ]] && [[ "$cnt" -gt 0 ]]; do
#     STATUS=$(aws ec2 describe-instances --region ${REGION} --instance ${MY_INSTANCE_ID}|jq -r --arg DEVICE "$DEVICE" '.Reservations[].Instances[].BlockDeviceMappings[]|select(.DeviceName==$DEVICE)|.Ebs.Status')
#     cnt=$(($cnt-1))
#     sleep 5
# done

if blkid ${DEVICE}; then
    echo "$DEVICE setup is fine"
else
    wipefs -fa $DEVICE && mkfs.ext4 $DEVICE
    # parted -s /dev/xvdb mklabel msdos && parted -s /dev/xvdb mkpart primary ext4 1MiB 100% && mkfs.ext4 /dev/xvdb1
fi
