#!/usr/bin/env bash
set -euo pipefail

dirs=(
docs
global/backend
global/iam/{policies,ai-roles}
global/org-policies
modules/network/{vpc,subnets,nat,routing}
modules/security/{security-groups,nsg,firewall}
modules/compute/{master-node,worker-node,autoscaling,launch-templates,gpu}
modules/kubernetes/{control-plane,node-groups,cni,bootstrap,templates,ai-node-pools,runtime-constraints}
modules/storage/{block,object,backups}
modules/observability/{logging,monitoring,tracing}
modules/access/{iam,oidc,rbac}
modules/shared/{labels,naming,tags}
environments/{dev,stage,prod}
policies/{opa,tfsec,checkov}/ai
policies/opa/terraform
ci
scripts
ai/{network,data,model-registry,training,inference}
governance/{policy-as-code,audit-rules,exception-workflows,compliance-mappings,decision-logs}
governance/policy-as-code/{opa,terraform,ci}
)

mkdir -p "${dirs[@]}"

files=(
.gitignore
README.md
.terraform-version
versions.tf

docs/{architecture.md,security-model.md,state-backend.md,workflows.md,break-glass.md,data-flows.md,repository-structure.md}

global/backend/{s3.tf,dynamodb.tf,kms.tf}
global/iam/{terraform-role.tf,attach.tf,break-glass.tf}
global/iam/policies/{terraform-base.tf,permission-boundary.tf}
global/iam/ai-roles/{data-access.tf,training.tf,inference.tf,mlops-ci.tf}
global/org-policies/{guardrails.tf,quotas.tf,scp.tf}

modules/{network,security,compute,kubernetes,observability,access}/{main.tf,variables.tf,outputs.tf}
modules/compute/gpu/{main.tf,variables.tf,outputs.tf}
modules/kubernetes/templates/{master_bootstrap.sh,worker_join.sh}
modules/kubernetes/ai-node-pools/{gpu-pool.tf,cpu-pool.tf,variables.tf,outputs.tf}
modules/kubernetes/runtime-constraints/{device-plugin.tf,seccomp.tf,variables.tf,outputs.tf}
modules/access/{iam,oidc,rbac}/main.tf
modules/shared/locals.tf
modules/shared/{labels,naming,tags}/{locals.tf,variables.tf,outputs.tf}
modules/storage/{block,object,backups}/.gitkeep

environments/{dev,stage,prod}/{backend.tf,providers.tf,main.tf,variables.tf,terraform.tfvars}

policies/opa/terraform/{naming.rego,tagging.rego,encryption.rego,regions.rego,README.md}
policies/opa/ai/{no-public-ai.rego,ai-data-isolation.rego,ai-gpu-restrictions.rego}
policies/tfsec/{tfsec.yml,ai/ai-storage.toml}
policies/checkov/{checkov.yml,ai/{ai_encryption.yaml,ai_network.yaml}}

ai/network/{egress-policy.tf,variables.tf,outputs.tf}
ai/data/{datasets.tf,access.tf,encryption.tf,lifecycle.tf,variables.tf,outputs.tf}
ai/model-registry/{models.tf,access.tf,encryption.tf,versioning.tf,variables.tf,outputs.tf}
ai/training/{namespace.tf,quotas.tf,network.tf,access.tf,variables.tf,outputs.tf}
ai/inference/{namespace.tf,access.tf,network.tf,runtime.tf,variables.tf,outputs.tf}

governance/policy-as-code/opa/{ai-network.rego,ai-data.rego,ai-models.rego,ai-training.rego,ai-inference.rego,ai-promotion.rego}
governance/policy-as-code/terraform/{mandatory-encryption.rego,no-public-ai.rego,region-lock.rego}
governance/policy-as-code/ci/policy-check.yml
governance/policy-as-code/README.md
governance/{audit-rules,exception-workflows,compliance-mappings,decision-logs}/.gitkeep

ci/{terraform-validate.yml,terraform-plan.yml,terraform-apply.yml,security-scan.yml}
scripts/{init.sh,plan.sh,apply.sh}
)

touch "${files[@]}"

echo "Terraform final project skeleton created."
