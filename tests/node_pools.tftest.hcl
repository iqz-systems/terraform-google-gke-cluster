mock_provider "google" {}

variables {
  project_id                = "test-project"
  cluster_region            = "us-east1"
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "test-cluster"
  node_service_account_name = "test-sa"
  subnetwork                = "test-subnet"
}

run "defaults_when_optional_fields_omitted" {
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
    }]
  }

  assert {
    condition     = length(google_container_node_pool.node_pool[0].node_config[0].labels) == 0
    error_message = "Labels must be empty by default."
  }

  assert {
    condition     = length(google_container_node_pool.node_pool[0].node_config[0].taint) == 0
    error_message = "No taints must be set by default."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].image_type == "cos_containerd"
    error_message = "The default image type must be cos_containerd."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].initial_node_count == 1
    error_message = "The default initial node count must be 1."
  }

  assert {
    condition     = google_container_cluster.cluster.release_channel[0].channel == "REGULAR"
    error_message = "The default release channel must be REGULAR."
  }
}

run "labels_and_taint_applied" {
  command = plan

  variables {
    node_pools = [{
      name                 = "databolt"
      machine_type         = "n2-standard-8"
      cluster_node_tags    = ["databolt"]
      min_node_count       = 0
      max_node_count       = 2
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      node_labels          = { workload = "databolt", tier = "compute" }
      node_taints          = [{ key = "dedicated", value = "databolt", effect = "NO_EXECUTE" }]
    }]
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].labels["workload"] == "databolt" && google_container_node_pool.node_pool[0].node_config[0].labels["tier"] == "compute"
    error_message = "Node labels were not applied."
  }

  assert {
    condition     = length(google_container_node_pool.node_pool[0].node_config[0].taint) == 1
    error_message = "Exactly one taint must be applied."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].taint[0].key == "dedicated" && google_container_node_pool.node_pool[0].node_config[0].taint[0].value == "databolt" && google_container_node_pool.node_pool[0].node_config[0].taint[0].effect == "NO_EXECUTE"
    error_message = "The taint was not applied as given."
  }
}

run "disk_and_image_applied" {
  command = plan

  variables {
    node_pools = [{
      name                 = "disk"
      machine_type         = "n2-standard-8"
      cluster_node_tags    = ["disk"]
      min_node_count       = 0
      max_node_count       = 2
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      disk_size_gb         = 200
      disk_type            = "pd-ssd"
      image_type           = "ubuntu_containerd"
    }]
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].disk_size_gb == 200
    error_message = "The disk size was not applied."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].disk_type == "pd-ssd"
    error_message = "The disk type was not applied."
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].node_config[0].image_type == "ubuntu_containerd"
    error_message = "The image type was not applied."
  }
}

run "initial_node_count_zero_honoured" {
  command = plan

  variables {
    node_pools = [
      {
        name                 = "empty"
        machine_type         = "e2-standard-4"
        cluster_node_tags    = ["empty"]
        min_node_count       = 0
        max_node_count       = 2
        spot_nodes           = false
        node_pool_node_zones = ["us-east1-b"]
        enable_private_nodes = true
        initial_node_count   = 0
      },
      {
        name                 = "default"
        machine_type         = "e2-standard-4"
        cluster_node_tags    = ["default"]
        min_node_count       = 0
        max_node_count       = 2
        spot_nodes           = false
        node_pool_node_zones = ["us-east1-b"]
        enable_private_nodes = true
      },
    ]
  }

  assert {
    condition     = google_container_node_pool.node_pool[0].initial_node_count == 0
    error_message = "An initial node count of 0 must be honoured."
  }

  assert {
    condition     = google_container_node_pool.node_pool[1].initial_node_count == 1
    error_message = "A pool without the field must keep an initial node count of 1."
  }
}

run "release_channel_override" {
  command = plan

  variables {
    release_channel = "STABLE"
    node_pools      = []
  }

  assert {
    condition     = google_container_cluster.cluster.release_channel[0].channel == "STABLE"
    error_message = "The release channel override was not applied."
  }
}

run "invalid_taint_effect_rejected" {
  command = plan

  variables {
    node_pools = [{
      name                 = "bad"
      machine_type         = "e2-standard-4"
      cluster_node_tags    = ["bad"]
      min_node_count       = 0
      max_node_count       = 1
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      node_taints          = [{ key = "k", value = "v", effect = "NoExecute" }]
    }]
  }

  expect_failures = [var.node_pools]
}

run "invalid_release_channel_rejected" {
  command = plan

  variables {
    release_channel = "NIGHTLY"
    node_pools      = []
  }

  expect_failures = [var.release_channel]
}
