resource "google_compute_network" "vpc_network" {
  name    = "${var.cluster_name}-network"
  project = data.google_project.current.project_id
}

resource "google_container_cluster" "cluster" {
  name        = var.cluster_name
  project     = data.google_project.current.project_id
  description = var.cluster_description

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  initial_node_count       = 1
  remove_default_node_pool = true

  location       = var.cluster_region
  node_locations = var.cluster_node_zones

  deletion_protection = var.disable_deletion_protection == true ? false : true

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

  maintenance_policy {
    daily_maintenance_window {
      start_time = "02:00" # 2 AM
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER", "WORKLOADS"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER"]
    managed_prometheus {
      enabled = var.enable_managed_prometheus
    }
  }

  lifecycle {
    ignore_changes = [
      node_version,
      node_pool.0.version,
    ]
  }
}

resource "google_container_node_pool" "node_pool" {
  count = length(var.node_pools)

  name           = var.node_pools[count.index].name
  project        = data.google_project.current.project_id
  location       = var.cluster_region
  cluster        = google_container_cluster.cluster.name
  node_locations = var.node_pools[count.index].node_pool_node_zones

  node_config {
    spot         = var.node_pools[count.index].spot_nodes
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

  network_config {
    enable_private_nodes = var.node_pools[count.index].enable_private_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  initial_node_count = 1

  autoscaling {
    total_min_node_count = var.node_pools[count.index].min_node_count
    total_max_node_count = var.node_pools[count.index].max_node_count
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  lifecycle {
    ignore_changes = [
      node_count,
      initial_node_count,
    ]
  }
}
