variable "vpc_id" {
  type = string
}

variable "ai_subnet_ids" {
  type = list(string)
}

variable "allowed_egress_cidrs" {
  type = list(string)
  default = []
}

variable "environment" {
  type = string
}
