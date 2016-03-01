#!/bin/bash

set -x
set -e

sed -i --follow-symlinks 's/^SELINUX=enforcing/SELINUX=disabled/' /etc/selinux/config
