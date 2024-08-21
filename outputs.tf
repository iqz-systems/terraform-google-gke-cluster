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

# Currently in beta
# output "cluster_notification_topic_id" {
#   value       = google_pubsub_topic.cluster_notifications.id
#   sensitive   = false
#   description = "The id of the topic where the cluster notifications are published."
# }
