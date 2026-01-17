package ai.network

deny[msg] {
  input.kind == "Service"
  input.spec.type == "LoadBalancer"
  not input.metadata.annotations["ai/approved-public"]
  msg := "AI сервисы не могут быть публичными без явного разрешения"
}
