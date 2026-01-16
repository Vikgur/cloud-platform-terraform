package terraform.tagging

required_tags := {"environment", "owner", "cost_center"}

deny[msg] {
  resource := input.resource_changes[_]
  missing := required_tags - object.keys(resource.change.after.tags)
  count(missing) > 0
  msg := sprintf("Missing required tags: %v", [missing])
}
