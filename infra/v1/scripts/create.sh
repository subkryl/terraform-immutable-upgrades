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
export TF_VAR_s3_bucket=${S3_BUCKET}

TFSTATE_KEY="terraform/$ENV/base"
export TF_VAR_tfstate_key=${TFSTATE_KEY}

TFSTATE_FILE="${__root}/.terraform/terraform.tfstate"

[ -z ${CONSUL_AMI_ID} ] && error "undefined CONSUL_AMI_ID"
export TF_VAR_consul_ami=${CONSUL_AMI_ID}

pushd ${__root}

# Remove local cached terraform.tfstate file. This is to avoid having a cached state file referencing another environment due to manual tests or wrong operations.
rm -f ${TFSTATE_FILE}
# terraform remote config -backend=s3 --backend-config="bucket=${S3_BUCKET}" --backend-config="key=$TFSTATE_KEY" --backend-config="region=${AWS_DEFAULT_REGION}"
TF_LOG=trace TF_LOG_PATH=init.log terraform init -backend=true --backend-config="bucket=${S3_BUCKET}" --backend-config="key=${TFSTATE_KEY}" --backend-config="region=${AWS_DEFAULT_REGION}"

TF_LOG=trace TF_LOG_PATH=plan.log terraform plan -input=false -var "env=$ENV" || error "terraform plan failed"

TF_LOG=trace TF_LOG_PATH=apply.log terraform apply -input=false -auto-approve -var "env=$ENV" || error "terraform apply failed"

# get states
# terraform output -json instance_ids
export TFSTATE=$(terraform state pull)

ALL_INSTANCE_IDS=$(tf_get_all_instance_ids ${TFSTATE})
aws ec2 wait instance-running --instance-ids ${ALL_INSTANCE_IDS} || error "some instances not active"

# Wait all instances are reachable via ssh
ansible-playbook -i ${__root}/scripts/terraform_to_ansible_inventory.sh ${__ansible}/wait_instance_up.yml

# Wait for all the consul server being active. Check this using the first consul server.
consul01ip=$(tf_get_instance_public_ip "consul_server01")
ansible-playbook -i ${consul01ip}, ${__ansible}/test_consul_servers_active.yml
