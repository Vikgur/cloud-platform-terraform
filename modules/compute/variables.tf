variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "instance_type_master" {
  type = string
}

variable "instance_type_worker" {
  type = string
}

variable "master_count" {
  type = number
}

variable "worker_min" {
  type = number
}

variable "worker_max" {
  type = number
}

variable "ami_id" {
  type = string
}

variable "key_name" {
  type = string
}

variable "security_group_master" {
  type = string
}

variable "security_group_worker" {
  type = string
}

variable "tags" {
  type = map(string)
}
