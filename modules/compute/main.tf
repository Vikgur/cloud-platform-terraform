resource "aws_iam_role" "ec2" {
  name = "ec2-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2" {
  name = "ec2-node-profile"
  role = aws_iam_role.ec2.name
}

resource "aws_launch_template" "worker" {
  name_prefix   = "worker-"
  image_id      = var.ami_id
  instance_type = var.instance_type_worker
  key_name      = var.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    security_groups = [var.security_group_worker]
  }

  tag_specifications {
    resource_type = "instance"
    tags          = var.tags
  }
}

resource "aws_autoscaling_group" "workers" {
  min_size         = var.worker_min
  max_size         = var.worker_max
  desired_capacity = var.worker_min

  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.worker.id
    version = "$Latest"
  }

  tag {
    key                 = "Role"
    value               = "worker"
    propagate_at_launch = true
  }
}

resource "aws_instance" "master" {
  count         = var.master_count
  ami           = var.ami_id
  instance_type = var.instance_type_master
  key_name      = var.key_name
  subnet_id     = element(var.subnet_ids, count.index)

  vpc_security_group_ids = [var.security_group_master]

  iam_instance_profile = aws_iam_instance_profile.ec2.name

  tags = merge(
    var.tags,
    {
      Role = "master"
      Name = "master-${count.index}"
    }
  )
}


