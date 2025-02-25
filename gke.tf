resource "google_compute_network" "vpc_network" {
  count   = var.create_vpc_network ? 1 : 0
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

  dynamic "private_cluster_config" {
    for_each = var.private_cluster_config == null ? [] : [var.private_cluster_config]
    content {
      enable_private_endpoint = private_cluster_config.value.enable_private_endpoint
      enable_private_nodes    = private_cluster_config.value.enable_private_nodes
      master_ipv4_cidr_block  = private_cluster_config.value.master_ipv4_cidr_block
    }
  }

  dynamic "master_authorized_networks_config" {
    for_each = var.master_authorized_networks_config
    content {
      cidr_blocks {
        cidr_block   = master_authorized_networks_config.value.cidr_block
        display_name = master_authorized_networks_config.value.display_name
      }
    }
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

  network = (!var.create_vpc_network && var.vpc_network != null) ? var.vpc_network : google_compute_network.vpc_network.0.name
  # Enable Dataplane V2
  # This also enables network policies by default.
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_ipv4_cidr_block  = "/16"
    services_ipv4_cidr_block = "/22"
  }

  dynamic "maintenance_policy" {
    for_each = var.maintenance_window != null ? [var.maintenance_window] : []
    content {
      recurring_window {
        start_time = maintenance_policy.value.start_time
        end_time   = maintenance_policy.value.end_time
        recurrence = maintenance_policy.value.recurrence
      }
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
