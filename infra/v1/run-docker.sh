#!/bin/bash

eval "$(ssh-agent -s)"
ssh-add $HOME/.ssh/${SSH_KEYPAIR}.pem

docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock -v $PWD/terraform:/deploy/.terraform -v "$SSH_AUTH_SOCK:/tmp/ssh_auth_sock" -e "SSH_AUTH_SOCK=/tmp/ssh_auth_sock" -e "ORIG_SSH_AUTH_SOCK=$SSH_AUTH_SOCK" -e ENV=${ENV} -e S3_BUCKET=${S3_BUCKET} -e SSH_KEYPAIR=${SSH_KEYPAIR} -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION infra:${VERSION} ${1}
