#!/bin/bash

set -x
set -e

STAGING_DIR="/tmp/packer/files/"
mkdir -p ${STAGING_DIR}
chown -R admin:admin ${STAGING_DIR}

chown root:root ${STAGING_DIR}/systemd/*
chown root:root ${STAGING_DIR}/_scripts/*
chmod +x ${STAGING_DIR}/_scripts/*

cp ${STAGING_DIR}/systemd/* /etc/systemd/system/
cp ${STAGING_DIR}/_scripts/* /usr/local/bin

