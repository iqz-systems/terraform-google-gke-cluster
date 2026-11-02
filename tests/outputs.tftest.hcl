mock_provider "google" {}

variables {
  project_id                = "test-project"
  cluster_region            = "us-east1"
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "test-cluster"
  node_service_account_name = "test-sa"
  subnetwork                = "test-subnet"

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
      name                 = "batch"
      machine_type         = "n2-standard-8"
      cluster_node_tags    = ["batch"]
      min_node_count       = 0
      max_node_count       = 2
      spot_nodes           = true
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
    },
  ]
}

run "cluster_outputs" {
  command = plan

  # The ID and endpoint are computed, so fixed values are supplied for the plan. The mock
  # provider cannot populate the master_auth block, so the CA certificate is checked as null.
  override_resource {
    target          = google_container_cluster.cluster
    override_during = plan
    values = {
      id       = "projects/test-project/locations/us-east1/clusters/test-cluster"
      endpoint = "203.0.113.10"
    }
  }

  assert {
    condition     = output.cluster_name == "test-cluster"
    error_message = "cluster_name must be the cluster's name."
  }

  assert {
    condition     = output.cluster_id == "projects/test-project/locations/us-east1/clusters/test-cluster"
    error_message = "cluster_id must be the cluster's ID."
  }

  assert {
    condition     = output.cluster_location == "us-east1"
    error_message = "cluster_location must be the cluster's location."
  }

  assert {
    condition     = output.cluster_endpoint == "203.0.113.10"
    error_message = "cluster_endpoint must be the cluster's endpoint."
  }

  assert {
    condition     = nonsensitive(output.cluster_ca_certificate) == null
    error_message = "cluster_ca_certificate must be null, without an error, while master_auth is empty."
  }

  assert {
    condition     = output.network_name == "test-cluster-network"
    error_message = "network_name must be the module-created network when create_vpc_network is true."
  }

  assert {
    condition     = output.node_pool_names == ["app", "batch"]
    error_message = "node_pool_names must list the node pools in input order."
  }
}

run "network_name_for_existing_vpc" {
  command = plan

  variables {
    create_vpc_network = false
    vpc_network        = "existing-vpc"
  }

  assert {
    condition     = output.network_name == "existing-vpc"
    error_message = "network_name must be the supplied network when create_vpc_network is false."
  }
}
