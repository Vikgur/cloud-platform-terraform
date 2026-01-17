deny[msg] {
  input.resource_type == "aws_s3_bucket"
  input.tags.purpose == "ai-data"
  not input.attributes.server_side_encryption_configuration
  msg := "AI datasets must be encrypted"
}
