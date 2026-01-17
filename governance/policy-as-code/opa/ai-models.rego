package ai.models

deny[msg] {
  input.kind == "Pod"
  input.metadata.namespace == "ai-inference"
  not input.metadata.annotations["ai/model-approved"]
  msg := "Inference может использовать только утверждённые модели"
}
