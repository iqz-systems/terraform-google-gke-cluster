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
