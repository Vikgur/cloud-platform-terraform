#!/bin/bash
set -euo pipefail

export TF_WORKSPACE=${ENVIRONMENT}

terraform workspace select ${TF_WORKSPACE} || terraform workspace new ${TF_WORKSPACE}

terraform plan -out=tfplan
