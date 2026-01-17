#!/usr/bin/env bash
set -e

dirs=(
global/iam/ai-roles
modules/compute/gpu
modules/kubernetes/ai-node-pools
modules/kubernetes/runtime-constraints
policies/{opa,tfsec,checkov}/ai
ai/{network,data,model-registry,training,inference}
governance/{policy-as-code,audit-rules,exception-workflows,compliance-mappings,decision-logs}
governance/policy-as-code/{opa,terraform,ci}
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
ai/network/{egress-policy.tf,variables.tf,outputs.tf}
ai/data/{datasets.tf,access.tf,encryption.tf,lifecycle.tf,variables.tf,outputs.tf}
ai/model-registry/{models.tf,access.tf,encryption.tf,versioning.tf,variables.tf,outputs.tf}
ai/training/{namespace.tf,quotas.tf,network.tf,access.tf,variables.tf,outputs.tf}
ai/inference/{namespace.tf,access.tf,network.tf,runtime.tf,variables.tf,outputs.tf}
governance/policy-as-code/opa/{ai-network.rego,ai-data.rego,ai-models.rego,ai-training.rego,ai-inference.rego,ai-promotion.rego}
governance/policy-as-code/terraform/{mandatory-encryption.rego,no-public-ai.rego,region-lock.rego}
governance/policy-as-code/ci/policy-check.yml
governance/policy-as-code/README.md
)

for f in "${files[@]}"; do
  touch "$f"
done

echo "AI skeleton created for Terraform project."
