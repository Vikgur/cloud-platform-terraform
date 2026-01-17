#!/usr/bin/env bash
set -e

dirs=(
global/iam/ai-roles
modules/compute/gpu
modules/kubernetes/ai-node-pools
modules/kubernetes/runtime-constraints
policies/{opa,tfsec,checkov}/ai
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

files=(
docs/{break-glass.md,data-flows.md}
global/iam/ai-roles/{data-access.tf,training.tf,inference.tf,mlops-ci.tf}  
modules/compute/gpu/{main.tf,variables.tf,outputs.tf}
modules/kubernetes/ai-node-pools/{gpu-pool.tf,cpu-pool.tf,variables.tf,outputs.tf}
modules/kubernetes/runtime-constraints/{device-plugin.tf,seccomp.tf,variables.tf,outputs.tf}
policies/opa/ai/{no-public-ai.rego,ai-data-isolation.rego,ai-gpu-restrictions.rego}
policies/checkov/ai/{ai_encryption.yaml,ai_network.yaml}
policies/tfsec/ai/ai-storage.toml
)

for f in "${files[@]}"; do
  touch "$f"
done

echo "AI skeleton created for Terraform project."
