#!/usr/bin/env bash

set -euf -o pipefail
export LC_ALL="C"

readonly BASE_DIR="$(realpath "$(dirname "$0")")"
export ANSIBLE_TF_WS_NAME=$(terraform workspace show)

"$BASE_DIR/terraform.py" > "$BASE_DIR/../ansible/terraform_aws_${ANSIBLE_TF_WS_NAME}_inventory"
