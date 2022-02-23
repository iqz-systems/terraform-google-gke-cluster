# terraform-google-gke-cluster

Terraform module to create a Google Kubernetes Engine cluster with Workload Identity enabled.

This module uses the [google](https://registry.terraform.io/providers/hashicorp/google) provider.

## Usage

```hcl
module "gke_cluster" {
  source            = "iqz-systems/gke-cluster/google"
  version           = "2.0.0"

  project_id          = "my_project"
  project_region      = "us-east1"
  project_zone        = "us-east1-b"
  cluster_region      = "us-east1"
  cluster_node_zones  = ["us-east1-b"]
  cluster_description = "GKE cluster for hosting production applications."
  cluster_name        = "my-cluster"
  node_pools = [{
    cluster_node_tags = [
      "my-cluster",
      "app-nodes"
    ]
    machine_type      = "e2-standard-4" # E2 machine type; 4 vCPU; 16GB RAM
    name              = "app-nodes"
    min_node_count    = 0
    max_node_count    = 3
    preemptible_nodes = false
    }, {
    cluster_node_tags = [
      "my-cluster",
      "demo-nodes"
    ]
    machine_type      = "n2-highmem-4" # N2 machine type; 4 vCPU; 32GB RAM
    name              = "pega-nodes"
    min_node_count    = 0
    max_node_count    = 3
    preemptible_nodes = true
  }]
  node_service_account_name = "my-service-account"
}
```

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/gke-cluster/google/latest)
