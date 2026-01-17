#!/usr/bin/env bash
set -e

dirs=(
global/iam/ai-roles
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

files=(
global/iam/ai-roles/{data-access.tf,training.tf,inference.tf,mlops-ci.tf}  
)

for f in "${files[@]}"; do
  touch "$f"
done

echo "AI skeleton created for Terraform project."
