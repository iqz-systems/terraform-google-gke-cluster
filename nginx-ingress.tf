resource "google_compute_address" "gke_ingress_ip" {
  name    = "${var.cluster_name}-ingress-ip"
  region  = var.project_region
  project = data.google_project.current.project_id
}

resource "helm_release" "nginx_ingress_controller" {
  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.0.17"

  namespace        = "ingress-nginx"
  create_namespace = true
  atomic           = true

  set {
    name  = "controller.service.loadBalancerIP"
    value = google_compute_address.gke_ingress_ip.address
  }
}
