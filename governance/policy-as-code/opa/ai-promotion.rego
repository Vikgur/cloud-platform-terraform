package ai.promotion

deny[msg] {
  input.kind == "Pod"
  input.metadata.namespace == "ai-inference"
  input.spec.volumes[_].namespace == "ai-training"
  msg := "Inference не может читать напрямую из training namespace"
}
