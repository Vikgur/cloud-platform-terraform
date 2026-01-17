resource "kubernetes_manifest" "seccomp_profile" {
  manifest = {
    apiVersion = "security-profiles-operator.x-k8s.io/v1beta1"
    kind       = "SeccompProfile"
    metadata = {
      name      = "ai-restricted"
      namespace = "kube-system"
    }
    spec = {
      defaultAction = "SCMP_ACT_ERRNO"
    }
  }
}
