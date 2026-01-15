output "ingress_sg_id" {
  value = aws_security_group.ingress.id
}

output "control_plane_sg_id" {
  value = aws_security_group.control_plane.id
}

output "workers_sg_id" {
  value = aws_security_group.workers.id
}
