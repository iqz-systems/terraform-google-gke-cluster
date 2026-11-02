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

run "module_vpc_created_by_default" {
  command = plan

  assert {
    condition     = length(google_compute_network.vpc_network) == 1
    error_message = "The module must create a VPC network by default."
  }

  assert {
    condition     = google_container_cluster.cluster.network == "test-cluster-network"
    error_message = "The cluster must use the module-created VPC network."
  }
}

run "existing_vpc_used" {
  command = plan

  variables {
    create_vpc_network = false
    vpc_network        = "existing-vpc"
  }

  assert {
    condition     = length(google_compute_network.vpc_network) == 0
    error_message = "No VPC network must be created when create_vpc_network is false."
  }

  assert {
    condition     = google_container_cluster.cluster.network == "existing-vpc"
    error_message = "The cluster must use the supplied VPC network."
  }
}

run "missing_vpc_network_rejected" {
  command = plan

  variables {
    create_vpc_network = false
    vpc_network        = null
  }

  expect_failures = [google_container_cluster.cluster]
}

run "ignored_vpc_network_warned" {
  command = plan

  variables {
    create_vpc_network = true
    vpc_network        = "existing-vpc"
  }

  expect_failures = [check.vpc_network_ignored]

  assert {
    condition     = google_container_cluster.cluster.network == "test-cluster-network"
    error_message = "The cluster must keep using the module-created VPC network."
  }
}
