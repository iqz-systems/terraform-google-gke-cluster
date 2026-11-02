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

run "default_id_from_cluster_name" {
  command = plan

  assert {
    condition     = google_service_account.k8s_sa.account_id == "test-cluster-sa"
    error_message = "The service account ID must default to <cluster_name>-sa."
  }
}

# 27 characters, giving a 30-character ID, which is the maximum allowed.
run "longest_cluster_name_accepted" {
  command = plan

  variables {
    cluster_name = "a-very-long-cluster-name-12"
  }

  assert {
    condition     = google_service_account.k8s_sa.account_id == "a-very-long-cluster-name-12-sa"
    error_message = "A 30-character service account ID must be accepted."
  }
}

run "long_cluster_name_with_override" {
  command = plan

  variables {
    cluster_name            = "a-very-long-cluster-name-123"
    node_service_account_id = "long-cluster-nodes"
  }

  assert {
    condition     = google_service_account.k8s_sa.account_id == "long-cluster-nodes"
    error_message = "The supplied node_service_account_id must be used."
  }
}

run "invalid_override_rejected" {
  command = plan

  variables {
    node_service_account_id = "Nodes_SA"
  }

  expect_failures = [var.node_service_account_id]
}
