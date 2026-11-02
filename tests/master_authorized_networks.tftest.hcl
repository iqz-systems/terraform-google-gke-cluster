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

run "no_authorized_networks_by_default" {
  command = plan

  assert {
    condition     = length(google_container_cluster.cluster.master_authorized_networks_config) == 0
    error_message = "No master_authorized_networks_config block must be set when the list is empty."
  }
}

run "single_authorized_network" {
  command = plan

  variables {
    master_authorized_networks_config = [
      { cidr_block = "10.0.0.0/8", display_name = "internal" },
    ]
  }

  assert {
    condition     = length(google_container_cluster.cluster.master_authorized_networks_config) == 1
    error_message = "Exactly one master_authorized_networks_config block must be set."
  }

  assert {
    condition     = toset([for b in google_container_cluster.cluster.master_authorized_networks_config[0].cidr_blocks : b.cidr_block]) == toset(["10.0.0.0/8"])
    error_message = "The authorized network was not applied."
  }
}

run "multiple_authorized_networks" {
  command = plan

  variables {
    master_authorized_networks_config = [
      { cidr_block = "10.0.0.0/8", display_name = "internal" },
      { cidr_block = "203.0.113.0/24", display_name = "office" },
    ]
  }

  assert {
    condition     = length(google_container_cluster.cluster.master_authorized_networks_config) == 1
    error_message = "All authorized networks must be in a single master_authorized_networks_config block."
  }

  assert {
    condition     = toset([for b in google_container_cluster.cluster.master_authorized_networks_config[0].cidr_blocks : b.cidr_block]) == toset(["10.0.0.0/8", "203.0.113.0/24"])
    error_message = "Both authorized networks must be applied as cidr_blocks."
  }

  assert {
    condition     = toset([for b in google_container_cluster.cluster.master_authorized_networks_config[0].cidr_blocks : b.display_name]) == toset(["internal", "office"])
    error_message = "The display names of the authorized networks were not applied."
  }
}
