#/bin/bash
set -ex

ENV_FILE=".env_vars"
if [[ -z "${ENV_FILE}" ]]; then
    echo "cp ENV_VARS --> ${ENV_FILE} && EDIT THE RIGHT VALUES"
    exit 1
fi
# source globals & export to ENV
set -a && source ${ENV_FILE} && set +a

export TF_VAR_access_key=${AWS_ACCESS_KEY_ID}
export TF_VAR_secret_key=${AWS_SECRET_ACCESS_KEY}
export TF_VAR_region=${AWS_DEFAULT_REGION}

terraform apply
