#!/bin/bash

set -x
set -e

if [ "${1}" == "test" ]; then
	TEST=1
else
	if [ -z ${VERSION} ]; then
		echo "VERSION env variable is missing!"
		exit 1
	fi
fi


packer build -machine-readable template.json | tee build.log
AMI_ID=$(grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2)

echo "AMI_ID: ${AMI_ID}"
if [ -z "${AMI_ID}" ]; then
	exit 1
fi

if [ -n "${TEST}" ]; then
	# Get ami's snapshot id
	SNAPSHOT_ID=$(aws ec2 describe-images --image-id ${AMI_ID} --query 'Images[*].BlockDeviceMappings[0].Ebs.SnapshotId' --output text)

	aws ec2 deregister-image --image-id ${AMI_ID}
	aws ec2 delete-snapshot --snapshot-id ${SNAPSHOT_ID}
else
	# Remove test tag added by packer template
	aws ec2 delete-tags --resources ${AMI_ID} --tags Key=test,Value=
	aws ec2 create-tags --resources ${AMI_ID} --tags Key=version,Value=${VERSION}
fi
