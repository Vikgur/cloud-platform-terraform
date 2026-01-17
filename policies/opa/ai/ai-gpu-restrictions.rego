deny[msg] {
  input.resource_type == "aws_eks_node_group"
  input.labels.workload == "ai-gpu"
  not input.taints
  msg := "GPU nodes must be tainted"
}
