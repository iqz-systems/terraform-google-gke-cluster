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

run "unmanaged_by_default" {
  command = plan

  assert {
    condition     = length(google_container_cluster.cluster.cost_management_config) == 0
    error_message = "cost_management_config must be left unset when enable_cost_allocation is null."
  }
}

run "cost_allocation_enabled" {
  command = plan

  variables {
    enable_cost_allocation = true
  }

  assert {
    condition     = google_container_cluster.cluster.cost_management_config[0].enabled == true
    error_message = "Cost allocation was not enabled."
  }
}

run "cost_allocation_disabled" {
  command = plan

  variables {
    enable_cost_allocation = false
  }

  assert {
    condition     = length(google_container_cluster.cluster.cost_management_config) == 1 && google_container_cluster.cluster.cost_management_config[0].enabled == false
    error_message = "cost_management_config must be set with enabled = false when enable_cost_allocation is false."
  }
}
