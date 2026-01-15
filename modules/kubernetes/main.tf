resource "random_password" "k3s_token" {
  length  = 32
  special = false
}

resource "null_resource" "master_bootstrap" {
  count = length(var.master_ips)

  connection {
    type        = "ssh"
    host        = var.master_ips[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      templatefile(
        "${path.module}/templates/master_bootstrap.sh",
        {
          token         = random_password.k3s_token.result
          cluster_name  = var.cluster_name
          k3s_version   = var.k3s_version
          pod_cidr      = var.pod_cidr
          service_cidr  = var.service_cidr
        }
      )
    ]
  }
}

resource "null_resource" "worker_join" {
  count = length(var.worker_ips)

  depends_on = [null_resource.master_bootstrap]

  connection {
    type        = "ssh"
    host        = var.worker_ips[count.index]
    user        = var.ssh_user
    private_key = file(var.ssh_private_key)
  }

  provisioner "remote-exec" {
    inline = [
      templatefile(
        "${path.module}/templates/worker_join.sh",
        {
          token        = random_password.k3s_token.result
          master_ip   = var.master_ips[0]
          k3s_version = var.k3s_version
        }
      )
    ]
  }
}

