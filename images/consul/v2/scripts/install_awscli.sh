#!/bin/bash

set -x
set -e

apt-get install -y python
wget https://bootstrap.pypa.io/get-pip.py
python get-pip.py
pip install awscli
