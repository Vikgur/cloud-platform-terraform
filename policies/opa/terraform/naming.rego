package terraform.naming

deny[msg] {
  resource := input.resource_changes[_]
  not startswith(resource.name, "prod-")
  msg := sprintf("Resource %s must start with prod-", [resource.name])
}
