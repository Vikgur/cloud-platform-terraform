package ai.security

deny[msg] {
  input.resource_type == "aws_lb"
  input.attributes.internal == false
  msg := "Public load balancers are forbidden for AI workloads"
}
