package terraform.regions

allowed := {"eu-central-1", "me-central-1"}

deny[msg] {
  resource := input.resource_changes[_]
  not allowed[resource.change.after.region]
  msg := "Region is not allowed by company policy"
}
