package terraform.encryption

deny[msg] {
  resource := input.resource_changes[_]
  resource.type == "aws_ebs_volume"
  not resource.change.after.encrypted
  msg := "EBS volume must be encrypted"
}
