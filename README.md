# terraform-google-gke-cluster

Terraform module to create a Google Kubernetes Engine cluster with Workload Identity enabled. This module also preconfigures the cluster with the [ingress-nginx controller](https://kubernetes.github.io/ingress-nginx/) and [cert-manager](https://cert-manager.io/).

This module uses the [google](https://registry.terraform.io/providers/hashicorp/google) provider.

## Usage

```hcl
module "gke_cluster" {
  source            = "iqz-systems/gke-cluster/google"
  version           = "1.0.0"

  project_id                = data.google_project.demo_project.project_id
  project_region            = "us-east1"
  project_zone              = "us-east1-b"
  cluster_region            = "us-east1
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "my-cluster"
  cluster_description       = "GKE cluster."
  node_service_account_name = "Service account."

  node_pools = [
    {
      name              = "app-nodes"
      machine_type      = "e2-standard-4" # E2 machine type; 4 vCPU; 16GB RAM
      cluster_node_tags = [
        "apps-cluster",
        "app-nodes"
      ]
    },
    {
      name              = "my-nodes"
      machine_type      = "e2-highmem-4" # E2 machine type; 4 vCPU; 32GB RAM
      cluster_node_tags = [
        "apps-cluster",
        "my-nodes"
      ]
    }
  ]
}
```

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/gke-cluster/google/latest)
