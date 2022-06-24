terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = ">=4.26.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.project_region
  zone    = var.project_zone
}

data "google_project" "current" {
}

resource "google_service_account" "k8s_sa" {
  account_id   = "${var.cluster_name}-sa"
  project      = data.google_project.current.project_id
  display_name = var.node_service_account_name
  description  = "Service account for ${var.cluster_name} GKE cluster."
}

# These bindings are necessary for the Kubernetes cluster to be able to pull
# images from Google Container Registry, and for writing logs.
resource "google_project_iam_member" "k8s_sa_storage" {
  # Refer: https://cloud.google.com/iam/docs/understanding-roles#cloud-storage-roles
  role    = "roles/storage.objectViewer"
  member  = "serviceAccount:${google_service_account.k8s_sa.email}"
  project = data.google_project.current.project_id
}

resource "google_project_iam_member" "k8s_sa_logging" {
  # Refer: https://cloud.google.com/iam/docs/understanding-roles#logging-roles
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.k8s_sa.email}"
  project = data.google_project.current.project_id
}

resource "google_project_iam_member" "k8s_sa_monitoring" {
  # Refer: https://cloud.google.com/iam/docs/understanding-roles#monitoring-roles
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.k8s_sa.email}"
  project = data.google_project.current.project_id
}
