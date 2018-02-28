#!/bin/bash

# A simple script that generates an ansible inventory from a terraform state file
set -x
set -e

__dir="$(readlink -f $(dirname ${0}))"
__root="$(readlink -f ${__dir}/../)"

TFSTATE_FILE="${__root}/.terraform/terraform.tfstate"

echo ${TFSTATE} | jq -c -e -r -M '{ all: .modules[0].resources | to_entries | map(select(.key | test("aws_instance\\..*"))) | map(.value.primary.attributes.public_ip) }'
