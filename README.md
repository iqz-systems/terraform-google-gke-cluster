# terraform-google-gke-cluster

Terraform module to create a Google Kubernetes Engine cluster with Workload Identity enabled. This module uses the [google](https://registry.terraform.io/providers/hashicorp/google/4.10.0) provider.

## Usage

```hcl
module "gke_cluster" {
  source            = "iqz-systems/gke-cluster/google"
  version           = "1.0.0"

  project_id                = data.google_project.demo_project.project_id
  project_region                    = "us-east1"
  project_zone                     = "us-east1-b"
  cluster_node_zones= ["us-east1-b"]
  cluster_name              = "${var.prefix}-cluster"
  machine_type              = "e2-standard-4"
  node_service_account_name = "IQZ Apps cluster service account"
  cluster_description       = "GKE cluster for hosting the internal IQZ apps."

  node_pools = [
    {
      name         = "app-nodes"
      machine_type = "e2-standard-4" # E2 machine type; 4 vCPU; 16GB RAM
      cluster_node_tags = [
        "iqz-apps-cluster",
        "app-nodes"
      ]
    },
    {
      name         = "pega-nodes"
      machine_type = "e2-highmem-4" # E2 machine type; 4 vCPU; 32GB RAM
      cluster_node_tags = [
        "iqz-apps-cluster",
        "pega-nodes"
      ]
    }
  ]
}
```

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/gke-cluster/google/latest)
