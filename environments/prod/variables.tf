variable "enable_gpu" {
  type    = bool
  default = false
}

variable "ai_region_lock" {
  type    = string
  default = "auto"
}

variable "model_storage_isolated" {
  type    = bool
  default = false
}
