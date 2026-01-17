#!/usr/bin/env bash
set -e

dirs=(
global/iam/ai-roles
modules/compute/gpu
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

files=(
global/iam/ai-roles/{data-access.tf,training.tf,inference.tf,mlops-ci.tf}  
modules/compute/gpu/{main.tf,variables.tf,outputs.tf}
)

for f in "${files[@]}"; do
  touch "$f"
done

echo "AI skeleton created for Terraform project."
