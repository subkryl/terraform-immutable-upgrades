#!/bin/bash

set -x
set -e

STAGING_DIR="/tmp/packer/files/"
mkdir -p ${STAGING_DIR}
chown -R fedora:fedora ${STAGING_DIR}

chown root:root ${STAGING_DIR}/systemd/*
chown root:root ${STAGING_DIR}/bin/*
chmod +x ${STAGING_DIR}/bin/*

cp ${STAGING_DIR}/systemd/* /etc/systemd/system/
cp ${STAGING_DIR}/bin/* /usr/local/bin

