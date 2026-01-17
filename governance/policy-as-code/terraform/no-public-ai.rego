package terraform.ai

deny[msg] {
  input.resource_type == "aws_lb"
  input.attributes.internal == false
  msg := "Публичные AI endpoints запрещены"
}
