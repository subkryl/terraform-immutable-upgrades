#!/bin/bash

set -x
set -e

__dir="$(readlink -f $(dirname ${0}))"
__root="$(readlink -f ${__dir}/../)"
__ansible="${__root}/ansible"

source ${__dir}/utils.sh

function cleanup() {
	${__dir}/destroy.sh
	delete_s3_object ${S3_BUCKET} ${TFSTATE_KEY}
}

env

[ -z ${AWS_ACCESS_KEY_ID} ] && error "missing AWS_ACCESS_KEY_ID environment variable"
[ -z ${AWS_SECRET_ACCESS_KEY} ] && error "missing SECRET_ACCESS_KEY environment variable"
[ -z ${AWS_DEFAULT_REGION} ] && error "missing AWS_DEFAULT_REGION environment variable"
[ -z ${S3_BUCKET} ] && error "missing S3_BUCKET environment variable"

# Generate a randon environment name
export ENV="test-$(uuidgen | cut -c1-8)"

TFSTATE_KEY="terraform/$ENV/base"

trap cleanup EXIT

pushd ${__root}

# Remove local cached terraform.tfstate file. Shouldn't exist since test
# environment is new but useful for local test runs.
rm -f .terraform/terraform.tfstate

${__dir}/create.sh || error "create failed"
