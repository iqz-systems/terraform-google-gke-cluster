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

run "node_service_account_roles" {
  command = plan

  assert {
    condition     = toset([for m in google_project_iam_member.k8s_sa_roles : m.role]) == toset(["roles/container.defaultNodeServiceAccount", "roles/artifactregistry.reader"])
    error_message = "The node service account must be granted exactly roles/container.defaultNodeServiceAccount and roles/artifactregistry.reader."
  }

  assert {
    condition     = alltrue([for m in google_project_iam_member.k8s_sa_roles : m.project == "test-project"])
    error_message = "The roles must be granted in the cluster's project."
  }
}
