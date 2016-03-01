#!/bin/bash

set -x
set -e

__dir="$(readlink -f $(dirname ${0}))"
__root="$(readlink -f ${__dir}/../)"
__ansible="${__root}/ansible"

source ${__dir}/utils.sh

case ${1} in
	"create")
		${__root}/scripts/create.sh
		;;
	"upgrade")
		${__root}/scripts/upgrade.sh
		;;
	"destroy")
		${__root}/scripts/destroy.sh
		;;
	"test-create")
		${__root}/scripts/test_create.sh
		;;
	"test-upgrade")
		${__root}/scripts/test_upgrade.sh
		;;
	*)
		error "Usage: ${0} {create|upgrade|destroy|test-create|test-upgrade}"
esac

