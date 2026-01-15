variable "master_ips" {
  type = list(string)
}

variable "worker_ips" {
  type = list(string)
}

variable "ssh_user" {
  type = string
}

variable "ssh_private_key" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "k3s_version" {
  type = string
}

variable "pod_cidr" {
  type = string
}

variable "service_cidr" {
  type = string
}
