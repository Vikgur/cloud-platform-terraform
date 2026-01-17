package ai.training

deny[msg] {
  input.kind == "Pod"
  input.metadata.namespace == "ai-training"
  not input.spec.nodeSelector["workload"]
  msg := "Training должен запускаться только на выделенных AI нодах"
}
