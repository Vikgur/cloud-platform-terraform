curl -sfL https://get.k3s.io | \
INSTALL_K3S_VERSION=${k3s_version} \
K3S_TOKEN=${token} \
sh -s - server \
  --cluster-init \
  --cluster-domain=${cluster_name} \
  --disable traefik \
  --disable servicelb \
  --pod-cidr=${pod_cidr} \
  --service-cidr=${service_cidr}
