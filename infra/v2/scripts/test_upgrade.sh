#!/bin/bash

set -e

__dir="$(readlink -f $(dirname ${0}))"
__root="$(readlink -f ${__dir}/../)"
__ansible="${__root}/ansible"

source ${__root}/config

source ${__dir}/utils.sh

function cleanup() {
    echo "w00ps / exiting"
	${__dir}/destroy.sh
	delete_s3_object ${S3_BUCKET} ${TFSTATE_KEY}
}

env

[ -z ${AWS_ACCESS_KEY_ID} ] && error "missing AWS_ACCESS_KEY_ID environment variable"
[ -z ${AWS_SECRET_ACCESS_KEY} ] && error "missing SECRET_ACCESS_KEY environment variable"
[ -z ${AWS_DEFAULT_REGION} ] && error "missing AWS_DEFAULT_REGION environment variable"
[ -z ${S3_BUCKET} ] && error "missing S3_BUCKET environment variable"
[ -z ${SSH_KEYPAIR} ] && error "missing SSH_KEYPAIR environment variable"

[ -z ${PREV_VERSION} ] && error "PREV_VERSION undefined, cannot test upgrade"

# Generate a randon environment name
export ENV="test-$(uuidgen | cut -c1-8)"

TFSTATE_KEY="terraform/$ENV/base"
TFSTATE_FILE="${__root}/.terraform/terraform.tfstate"

trap cleanup EXIT

pushd ${__root}

# Remove old remote tfstate
delete_s3_object ${S3_BUCKET} ${TFSTATE_KEY}

# Remove local cached terraform.tfstate file. Shouldn't exist since test environment is new.
rm -f ${TFSTATE_FILE}

# Create ourself from previous version
docker run -it -v "$ORIG_SSH_AUTH_SOCK:/tmp/ssh_auth_sock" -e "SSH_AUTH_SOCK=/tmp/ssh_auth_sock" -e ENV=${ENV} -e S3_BUCKET=${S3_BUCKET} -e SSH_KEYPAIR=${SSH_KEYPAIR} -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION infra:${PREV_VERSION} create

# Run upgrade on current version

${__dir}/upgrade.sh || die "upgrade failed"
