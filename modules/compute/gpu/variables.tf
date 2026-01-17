variable "instance_type" {
  type        = string
  description = "GPU instance type (e.g. g5.xlarge)"
}

variable "instance_profile_name" {
  type        = string
  description = "IAM profile for GPU nodes"
}
