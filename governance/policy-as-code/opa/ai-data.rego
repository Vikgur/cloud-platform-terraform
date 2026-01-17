package ai.data

deny[msg] {
  input.kind == "Pod"
  input.metadata.namespace == "ai-training"
  input.spec.volumes[_].persistentVolumeClaim.claimName == "shared-data"
  msg := "Training не должен монтировать общие датасеты"
}
