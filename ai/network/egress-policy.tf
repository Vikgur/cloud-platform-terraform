resource "aws_security_group" "ai_egress" {
  name        = "ai-egress-${var.environment}"
  description = "Restricted egress for AI workloads"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = var.allowed_egress_cidrs
  }

  revoke_rules_on_delete = true
}
