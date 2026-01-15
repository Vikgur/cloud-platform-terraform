#!/usr/bin/env bash
set -e

dirs=(
docs
global/backend
global/iam/policies
global/org-policies
modules/network/{vpc,subnets,nat,routing}
modules/security/{security-groups,nsg,firewall}
modules/compute/{master-node,worker-node,autoscaling,launch-templates}
modules/kubernetes/{control-plane,node-groups,cni,bootstrap}
modules/storage/{block,object,backups}
modules/observability/{logging,monitoring,tracing}
modules/access/{iam,oidc,rbac}
modules/shared/{labels,naming,tags}
environments/{dev,stage,prod}
policies/{opa,tfsec,checkov}
ci
scripts
)

for d in "${dirs[@]}"; do
  mkdir -p "$d"
done

files=(
README.md
docs/{architecture.md,security-model.md,state-backend.md,workflows.md}
global/backend/{s3.tf,dynamodb.tf,kms.tf}
global/iam/terraform-role.tf
global/iam/policies/{terraform-base.tf,permission-boundary.tf}
global/iam/attach.tf
global/iam/break-glass.tf
global/org-policies/{guardrails.tf,quotas.tf,scp.tf}
modules/network/{outputs.tf,variables.tf,main.tf}
modules/security/{outputs.tf,variables.tf,main.tf}
modules/compute/{outputs.tf,variables.tf,main.tf}
modules/shared/locals.tf
modules/shared/naming/{locals.tf,variables.tf,outputs.tf}
modules/shared/tags/{locals.tf,variables.tf,outputs.tf}
modules/shared/labels/{locals.tf,variables.tf,outputs.tf}
environments/dev/{backend.tf,providers.tf,main.tf,variables.tf,terraform.tfvars}
environments/stage/{backend.tf,providers.tf,main.tf,variables.tf,terraform.tfvars}
environments/prod/{backend.tf,providers.tf,main.tf,variables.tf,terraform.tfvars}
policies/opa/terraform.rego
ci/{terraform-validate.yml,terraform-plan.yml,terraform-apply.yml,security-scan.yml}
scripts/{init.sh,plan.sh,apply.sh}
.terraform-version
)

for f in "${files[@]}"; do
  touch "$f"
done

echo "Terraform project skeleton created."
