mock_provider "google" {}

variables {
  project_id                = "test-project"
  cluster_region            = "us-east1"
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "test-cluster"
  node_service_account_name = "test-sa"
  subnetwork                = "test-subnet"

  node_pools = [{
    name                 = "app"
    machine_type         = "e2-standard-4"
    cluster_node_tags    = ["app"]
    min_node_count       = 0
    max_node_count       = 3
    spot_nodes           = false
    node_pool_node_zones = ["us-east1-b"]
    enable_private_nodes = true
  }]
}

run "defaults_unchanged" {
  command = plan

  assert {
    condition     = google_container_cluster.cluster.resource_labels == tomap({ project = "test-project" })
    error_message = "The cluster must carry only the project label by default."
  }

  assert {
    condition     = toset(google_container_cluster.cluster.logging_config[0].enable_components) == toset(["SYSTEM_COMPONENTS", "APISERVER", "CONTROLLER_MANAGER", "SCHEDULER", "WORKLOADS"])
    error_message = "The default logging components must be unchanged."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].upgrade_settings[0].max_surge == 1 && google_container_node_pool.node_pool[0].upgrade_settings[0].max_unavailable == 0
    error_message = "The default surge upgrade settings must be max_surge 1 and max_unavailable 0."
  }
}

run "cluster_overrides" {
  command = plan

  variables {
    resource_labels    = { team = "data", project = "ignored" }
    logging_components = ["SYSTEM_COMPONENTS", "WORKLOADS"]
  }

  assert {
    condition     = google_container_cluster.cluster.resource_labels == tomap({ team = "data", project = "test-project" })
    error_message = "Extra labels must be merged, and the project label must not be overridable."
  }

  assert {
    condition     = toset(google_container_cluster.cluster.logging_config[0].enable_components) == toset(["SYSTEM_COMPONENTS", "WORKLOADS"])
    error_message = "The logging components were not applied."
  }
}

run "node_pool_overrides" {
  command = plan

  variables {
    node_pools = [{
      name                 = "app"
      machine_type         = "e2-standard-4"
      cluster_node_tags    = ["app"]
      min_node_count       = 0
      max_node_count       = 3
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      max_surge            = 2
      max_unavailable      = 1
      max_pods_per_node    = 64
      enable_secure_boot   = true
    }]
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].upgrade_settings[0].max_surge == 2 && google_container_node_pool.node_pool[0].upgrade_settings[0].max_unavailable == 1
    error_message = "The surge upgrade settings were not applied."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].max_pods_per_node == 64
    error_message = "max_pods_per_node was not applied."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].shielded_instance_config[0].enable_secure_boot == true
    error_message = "Secure boot was not enabled."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].shielded_instance_config[0].enable_integrity_monitoring == true
    error_message = "Integrity monitoring must stay enabled when secure boot is enabled."
  }
}

run "min_above_max_rejected" {
  command = plan

  variables {
    node_pools = [{
      name                 = "app"
      machine_type         = "e2-standard-4"
      cluster_node_tags    = ["app"]
      min_node_count       = 4
      max_node_count       = 3
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
    }]
  }

  expect_failures = [var.node_pools]
}

run "duplicate_pool_names_rejected" {
  command = plan

  variables {
    node_pools = [
      {
        name                 = "app"
        machine_type         = "e2-standard-4"
        cluster_node_tags    = ["app"]
        min_node_count       = 0
        max_node_count       = 3
        spot_nodes           = false
        node_pool_node_zones = ["us-east1-b"]
        enable_private_nodes = true
      },
      {
        name                 = "app"
        machine_type         = "n2-standard-8"
        cluster_node_tags    = ["app"]
        min_node_count       = 0
        max_node_count       = 2
        spot_nodes           = true
        node_pool_node_zones = ["us-east1-b"]
        enable_private_nodes = true
      },
    ]
  }

  expect_failures = [var.node_pools]
}

run "zero_surge_and_unavailable_rejected" {
  command = plan

  variables {
    node_pools = [{
      name                 = "app"
      machine_type         = "e2-standard-4"
      cluster_node_tags    = ["app"]
      min_node_count       = 0
      max_node_count       = 3
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      max_surge            = 0
      max_unavailable      = 0
    }]
  }

  expect_failures = [var.node_pools]
}
