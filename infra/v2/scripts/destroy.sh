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

export TF_VAR_consul_ami="IDONTCARE"

# Remove local cached terraform.tfstate file. This is to avoid having a cached state file referencing another environment due to manual tests or wrong operations.
rm -f ${TFSTATE_FILE}
# terraform remote config -backend=s3 --backend-config="bucket=${S3_BUCKET}" --backend-config="key=$TFSTATE_KEY" --backend-config="region=${AWS_DEFAULT_REGION}"
terraform init -backend=true --backend-config="bucket=${S3_BUCKET}" --backend-config="key=${TFSTATE_KEY}" --backend-config="region=${AWS_DEFAULT_REGION}"

# get states
# terraform output -json instance_ids
export TFSTATE=$(terraform state pull)

# shutdown instance before doing terraform apply or it will fail to remove the aws_volume_attachment since it's mounted. See also https://github.com/hashicorp/terraform/issues/2957
INSTANCE_IDS=$(tf_get_all_instance_ids ${TFSTATE})
if [ ${INSTANCE_IDS} != "[]" ]; then
	aws ec2 stop-instances --instance-ids ${INSTANCE_IDS}
	aws ec2 wait instance-stopped --instance-ids ${INSTANCE_IDS} || error "some instance are not stopped"
fi

terraform destroy -input=false -force -var "env=$ENV" || error "terraform plan failed"
