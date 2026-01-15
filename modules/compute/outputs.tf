output "master_ids" {
  value = aws_instance.master[*].id
}

output "worker_asg_name" {
  value = aws_autoscaling_group.workers.name
}

output "worker_launch_template" {
  value = aws_launch_template.worker.id
}
