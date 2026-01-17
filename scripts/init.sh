#!/bin/bash
set -euo pipefail

# bootstrap backend
aws s3api create-bucket --bucket "company-${ENVIRONMENT}-tfstate" || true
aws dynamodb create-table \
  --table-name "terraform-locks-${ENVIRONMENT}" \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST || true

# export env vars
export TF_WORKSPACE=${ENVIRONMENT}

# terraform init
terraform init -backend-config="bucket=company-${ENVIRONMENT}-tfstate" \
               -backend-config="dynamodb_table=terraform-locks-${ENVIRONMENT}" \
               -backend-config="key=terraform.tfstate"
