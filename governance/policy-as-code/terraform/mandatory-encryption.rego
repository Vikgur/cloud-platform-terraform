package terraform.security

deny[msg] {
  input.resource_type == "aws_s3_bucket"
  not input.attributes.server_side_encryption_configuration
  msg := "Все AI-хранилища должны быть зашифрованы"
}
