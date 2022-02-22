output "k8s_host" {
  value       = module.gke_auth.host
  description = "The host address of the Kubernetes cluster."
}

output "k8s_token" {
  value       = module.gke_auth.token
  sensitive   = true
  description = "The OAuth token which can be used to authenticate with the cluster."
}

output "k8s_cluster_ca_certificate" {
  value       = module.gke_auth.cluster_ca_certificate
  sensitive   = true
  description = "The kubernetes cluster CA certificate."
}

output "k8s_kubeconfig" {
  value       = module.gke_auth.kubeconfig_raw
  sensitive   = true
  description = "The raw kubeconfig file for the cluster."
}

output "service_account_email" {
  value       = google_service_account.k8s_sa.email
  sensitive   = false
  description = "The service account associated with the cluster."
}

output "ingress_ip" {
  value       = google_compute_address.gke_ingress_ip.address
  sensitive   = false
  description = "The IP address of the pre-installed ingress controller."
}
