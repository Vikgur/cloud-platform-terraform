resource "aws_launch_template" "gpu" {
  name_prefix = "gpu-nodes-"

  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  metadata_options {
    http_tokens = "required"
  }
}
