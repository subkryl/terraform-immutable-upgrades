#!/bin/bash

set -e

__dir="$(readlink -f $(dirname ${0}))"
__root="$(readlink -f ${__dir}/../)"
__ansible="${__root}/ansible"

source ${__root}/config

source ${__dir}/utils.sh

[ -z ${ENV} ] && error "missing ENV environment variable"
[ -z ${AWS_ACCESS_KEY_ID} ] && error "missing AWS_ACCESS_KEY_ID environment variable"
[ -z ${AWS_SECRET_ACCESS_KEY} ] && error "missing SECRET_ACCESS_KEY environment variable"
[ -z ${AWS_DEFAULT_REGION} ] && error "missing AWS_DEFAULT_REGION environment variable"
[ -z ${S3_BUCKET} ] && error "missing S3_BUCKET environment variable"
[ -z ${SSH_KEYPAIR} ] && error "missing SSH_KEYPAIR environment variable"

export TF_VAR_access_key=${AWS_ACCESS_KEY_ID}
export TF_VAR_secret_key=${AWS_SECRET_ACCESS_KEY}
export TF_VAR_region=${AWS_DEFAULT_REGION}
export TF_VAR_ssh_keypair=${SSH_KEYPAIR}

TFSTATE_KEY="terraform/$ENV/base"
TFSTATE_FILE="${__root}/.terraform/terraform.tfstate"

[ -z ${CONSUL_AMI_ID} ] && error "undefined CONSUL_AMI_ID"
export TF_VAR_consul_ami=${CONSUL_AMI_ID}


pushd ${__root}

# Remove local cached terraform.tfstate file. This is to avoid having a cached state file referencing another environment due to manual tests or wrong operations.
rm -f ${TFSTATE_FILE}
TF_LOG=trace TF_LOG_PATH=init.log terraform init -backend=true --backend-config="bucket=${S3_BUCKET}" --backend-config="key=${TFSTATE_KEY}" --backend-config="region=${AWS_DEFAULT_REGION}"

# get states
# terraform output -json instance_ids
export TFSTATE=$(terraform state pull)

# Consul server upgrade
# Test all consul servers are active. Check this using the first consul server.
consul01ip=$(tf_get_instance_public_ip "consul_server01")
ansible-playbook -i ${consul01ip}, ${__ansible}/test_consul_servers_active.yml

## Rolling upgrade of consul server
for id in 01 02 03; do
	INSTANCE_ID=$(tf_get_instance_id "consul_server${id}")
	if [ -z ${INSTANCE_ID} ]; then
		error "empty instance id"
	fi

	# check for changes
	set +e
	TF_LOG=trace TF_LOG_PATH=plan.log terraform plan -detailed-exitcode -input=false -var "env=$ENV" -target aws_instance.consul_server${id} -target aws_volume_attachment.consul_server${id}_ebs_attachment
	if [ $? -eq 0 ]; then
		echo "no changes for instance ${instance}"
		continue
	fi
	set -e

	# shutdown instance before doing terraform apply or it will fail to remove the aws_volume_attachment since it's mounted. See also https://github.com/hashicorp/terraform/issues/2957
	aws ec2 stop-instances --instance-ids ${INSTANCE_ID}
	aws ec2 wait instance-stopped --instance-ids ${INSTANCE_ID} || error "instance ${INSTANCE_ID} is not stopped"

	# recreate instance
	TF_LOG=trace TF_LOG_PATH=apply.log terraform apply -input=false -auto-approve -var "env=$ENV" -target aws_instance.consul_server${id} -target aws_volume_attachment.consul_server${id}_ebs_attachment

	# refresh TFSTATE
	export TFSTATE=$(terraform state pull)

	# Get the new instance id
	INSTANCE_ID=$(tf_get_instance_id consul_server${id})
	if [ -z ${INSTANCE_ID} ]; then
		error "empty instance id"
	fi
	aws ec2 wait instance-running --instance-ids ${INSTANCE_ID} || error "instance ${INSTANCE_ID} not running"

	INSTANCE_PUBLIC_IP=$(tf_get_instance_public_ip consul_server${id})
	# Wait for the consul server instance being reachable via ssh
	ansible-playbook -i ${INSTANCE_PUBLIC_IP}, ${__ansible}/wait_instance_up.yml

	# Wait for all the consul server being active
	ansible-playbook -i ${INSTANCE_PUBLIC_IP}, ${__ansible}/test_consul_servers_active.yml

done


# Finally check that all the changes were applied
# If there're some changes left behind, then we forgot to do something.
echo "Checking that no changes were left behind"
set +e
TF_LOG=trace TF_LOG_PATH=plan.log terraform plan -detailed-exitcode -input=false -var "env=$ENV"
ret=$?
if [ ${ret} -eq 1 ]; then
	error "terraform plan error!"
fi
if [ ${ret} -eq 2 ]; then
	error "some changes were left behind!"
fi
set -e
