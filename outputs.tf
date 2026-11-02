output "service_account_email" {
  value       = google_service_account.k8s_sa.email
  sensitive   = false
  description = "The service account associated with the cluster."
}

output "service_account_id" {
  value       = google_service_account.k8s_sa.id
  sensitive   = false
  description = "The id of the service account associated with the cluster."
}

output "cluster_name" {
  value       = google_container_cluster.cluster.name
  description = "The name of the cluster."
}

output "cluster_id" {
  value       = google_container_cluster.cluster.id
  description = "The ID of the cluster, in the form projects/<project>/locations/<location>/clusters/<name>."
}

output "cluster_location" {
  value       = google_container_cluster.cluster.location
  description = "The location of the cluster: a region for a regional cluster or a zone for a zonal cluster."
}

output "cluster_endpoint" {
  value       = google_container_cluster.cluster.endpoint
  description = "The IP address of the cluster's control plane endpoint."
}

output "cluster_ca_certificate" {
  value       = one(google_container_cluster.cluster.master_auth[*].cluster_ca_certificate)
  sensitive   = true
  description = "The base64-encoded public CA certificate of the cluster's control plane."
}

output "network_name" {
  value       = google_container_cluster.cluster.network
  description = "The name of the VPC network the cluster uses."
}

output "node_pool_names" {
  value       = [for pool in google_container_node_pool.node_pool : pool.name]
  description = "The names of the cluster's node pools, in the order of the node_pools input."
}
