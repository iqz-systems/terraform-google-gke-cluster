resource "google_compute_network" "vpc_network" {
  name    = "${var.cluster_name}-network"
  project = data.google_project.current.project_id
}

# Currently in beta
# resource "google_pubsub_topic" "cluster_notifications" {
#   name    = "${var.cluster_name}-notifications"
#   project = data.google_project.current.project_id

#   labels = {
#     type         = "cluster_notification"
#     cluster_name = google_container_cluster.cluster.name
#   }

#   message_retention_duration = "86400s" # 1 day
# }

resource "google_container_cluster" "cluster" {
  name        = var.cluster_name
  project     = data.google_project.current.project_id
  description = var.cluster_description

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true

  location           = var.cluster_region
  node_locations     = var.cluster_node_zones
  initial_node_count = 1

  vertical_pod_autoscaling {
    enabled = true
  }

  # Workload identity enables an application running on GKE to authenticate to
  # Google Cloud using a Kubernetes Service Account (KSA). This works by mapping
  # a KSA to a Google Service Account (GSA).
  # Refer: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity#authenticating_to
  workload_identity_config {
    workload_pool = "${data.google_project.current.project_id}.svc.id.goog"
  }

  logging_service    = "logging.googleapis.com/kubernetes"
  monitoring_service = "monitoring.googleapis.com/kubernetes"

  resource_labels = {
    "project" = data.google_project.current.project_id
  }

  network = google_compute_network.vpc_network.name
  # Enable Dataplane V2
  # This also enables network policies by default.
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }

  # Currently in beta
  # notification_config {
  #   pubsub {
  #     enabled = var.enable_notifications
  #     topic   = google_pubsub_topic.cluster_notifications.id
  #   }
  # }

  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00" # 2 AM
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  lifecycle {
    ignore_changes = [
      node_version,
      node_pool.0.version
    ]
  }
}

resource "google_container_node_pool" "node_pool" {
  count = length(var.node_pools)

  name           = "${var.cluster_name}-${var.node_pools[count.index].name}"
  project        = data.google_project.current.project_id
  location       = var.project_region
  cluster        = google_container_cluster.cluster.name
  node_count     = var.node_pools[count.index].min_node_count
  node_locations = var.cluster_node_zones

  node_config {
    preemptible  = false
    machine_type = var.node_pools[count.index].machine_type
    image_type   = "cos_containerd"

    metadata = {
      "disable-legacy-endpoints" = "true" # Do not remove this value
    }

    gcfs_config {
      enabled = true
    }

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.k8s_sa.email
    oauth_scopes = [
      # Refer: https://cloud.google.com/sdk/gcloud/reference/container/node-pools/create
      "https://www.googleapis.com/auth/cloud-platform",
      "https://www.googleapis.com/auth/devstorage.read_only", # Allows image pull from GCR
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/service.management.readonly",
      "https://www.googleapis.com/auth/servicecontrol",
      "https://www.googleapis.com/auth/trace.append",
    ]

    tags = var.node_pools[count.index].cluster_node_tags

    workload_metadata_config {
      mode = "GKE_METADATA"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  autoscaling {
    min_node_count = var.node_pools[count.index].min_node_count
    max_node_count = var.node_pools[count.index].max_node_count
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      node_count,
    ]
  }
}

# https://github.com/terraform-google-modules/terraform-google-kubernetes-engine/tree/master/modules/auth
module "gke_auth" {
  source     = "terraform-google-modules/kubernetes-engine/google//modules/auth"
  project_id = data.google_project.current.project_id

  cluster_name = google_container_cluster.cluster.name
  location     = var.project_region
}
