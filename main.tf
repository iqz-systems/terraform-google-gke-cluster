terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=7.12.0"
    }
  }
}

data "google_project" "current" {
  project_id = var.project_id
}

resource "google_service_account" "k8s_sa" {
  account_id   = coalesce(var.node_service_account_id, "${var.cluster_name}-sa")
  project      = data.google_project.current.project_id
  display_name = var.node_service_account_name
  description  = "Service account for ${var.cluster_name} GKE cluster."
}

# roles/container.defaultNodeServiceAccount covers logging, monitoring and metadata writes;
# roles/artifactregistry.reader allows nodes to pull images from the project's repositories.
# Refer: https://cloud.google.com/kubernetes-engine/docs/how-to/service-accounts#default-gke-service-agent
resource "google_project_iam_member" "k8s_sa_roles" {
  for_each = toset([
    "roles/container.defaultNodeServiceAccount",
    "roles/artifactregistry.reader",
  ])

  role    = each.value
  member  = "serviceAccount:${google_service_account.k8s_sa.email}"
  project = data.google_project.current.project_id
}
