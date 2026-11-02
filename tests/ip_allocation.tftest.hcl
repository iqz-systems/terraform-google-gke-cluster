mock_provider "google" {}

variables {
  project_id                = "test-project"
  cluster_region            = "us-east1"
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "test-cluster"
  node_service_account_name = "test-sa"
  subnetwork                = "test-subnet"
  create_vpc_network        = false
  vpc_network               = "shared-vpc"

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

run "netmasks_by_default" {
  command = plan

  assert {
    condition     = google_container_cluster.cluster.ip_allocation_policy[0].cluster_ipv4_cidr_block == "/16"
    error_message = "Pods must use a /16 netmask by default."
  }

  assert {
    condition     = google_container_cluster.cluster.ip_allocation_policy[0].services_ipv4_cidr_block == "/22"
    error_message = "Services must use a /22 netmask by default."
  }
}

# The CIDR block attributes are computed by the provider when unset, so only the names are asserted.
run "named_secondary_ranges" {
  command = plan

  variables {
    secondary_range_names = {
      pods     = "gke-pods"
      services = "gke-services"
    }
  }

  assert {
    condition     = google_container_cluster.cluster.ip_allocation_policy[0].cluster_secondary_range_name == "gke-pods"
    error_message = "The pods secondary range name was not applied."
  }

  assert {
    condition     = google_container_cluster.cluster.ip_allocation_policy[0].services_secondary_range_name == "gke-services"
    error_message = "The services secondary range name was not applied."
  }
}
