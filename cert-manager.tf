resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  version    = "v1.7.1"

  namespace        = "cert-manager"
  create_namespace = true
  atomic           = true

  set {
    name  = "installCRDs"
    value = "true"
  }

  set {
    name  = "global.leaderElection.namespace"
    value = "cert-manager"
  }

  depends_on = [
    helm_release.nginx_ingress_controller
  ]
}

resource "local_file" "kube_config_file" {
  sensitive_content = module.gke_auth.kubeconfig_raw
  filename          = "${path.module}/kube_config"

  depends_on = [
    helm_release.cert_manager
  ]
}

resource "null_resource" "letsencrypt_crd" {
  provisioner "local-exec" {
    command = "kubectl --kubeconfig ${path.module}/kube_config apply -f letsencrypt.clusterissuer.yaml"
  }

  depends_on = [
    local_file.kube_config_file
  ]
}
