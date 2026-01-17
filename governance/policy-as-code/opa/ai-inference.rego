package ai.inference

deny[msg] {
  input.kind == "Pod"
  input.metadata.namespace == "ai-inference"
  input.spec.securityContext.privileged == true
  msg := "Inference не может быть privileged"
}
