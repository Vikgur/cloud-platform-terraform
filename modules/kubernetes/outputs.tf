output "kubeconfig_path" {
  value = "/etc/rancher/k3s/k3s.yaml"
}

output "cluster_name" {
  value = var.cluster_name
}

output "k3s_token" {
  value     = random_password.k3s_token.result
  sensitive = true
}
