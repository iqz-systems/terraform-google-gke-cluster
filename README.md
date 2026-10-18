# terraform-google-gke-cluster

Terraform module to create a Google Kubernetes Engine cluster with Workload Identity enabled, separately managed node pools and a dedicated node service account.

This module uses the [google](https://registry.terraform.io/providers/hashicorp/google) provider, version 7.12.0 or later.

## Usage

```hcl
module "gke_cluster" {
  source  = "iqz-systems/gke-cluster/google"
  version = "8.2.0"

  cluster_region            = "us-east1"
  cluster_node_zones        = ["us-east1-b"]
  cluster_name              = "my-cluster"
  cluster_description       = "GKE cluster for hosting production applications."
  node_service_account_name = "my-service-account"
  subnetwork                = "my-subnetwork"
  release_channel           = "REGULAR"

  create_vpc_network = false
  vpc_network        = "my-vpc"

  node_pools = [
    {
      name                 = "app-nodes"
      machine_type         = "e2-standard-4"
      cluster_node_tags    = ["my-cluster", "app-nodes"]
      min_node_count       = 0
      max_node_count       = 3
      spot_nodes           = false
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
    },
    {
      name                 = "databolt-nodes"
      machine_type         = "n2-highmem-4"
      cluster_node_tags    = ["my-cluster", "databolt-nodes"]
      min_node_count       = 0
      max_node_count       = 3
      spot_nodes           = true
      node_pool_node_zones = ["us-east1-b"]
      enable_private_nodes = true
      node_labels          = { workload = "databolt" }
      node_taints          = [{ key = "dedicated", value = "databolt", effect = "NO_EXECUTE" }]
      disk_size_gb         = 200
      disk_type            = "pd-ssd"
      initial_node_count   = 0
      image_type           = "cos_containerd"
    },
  ]
}
```

## Inputs

### Cluster

- `project_id` (string, default `null`): The project in which the resources are created. When null, the project of the google provider configuration is used.
- `cluster_region` (string, required): The region where the cluster master is created.
- `cluster_node_zones` (list of string, required): The zones for the cluster nodes.
- `cluster_name` (string, required): The name of the cluster.
- `cluster_description` (string, default `""`): The description associated with the cluster.
- `release_channel` (string, default `"REGULAR"`): The GKE release channel. Allowed values are UNSPECIFIED, RAPID, REGULAR, STABLE and EXTENDED.
- `node_service_account_name` (string, required): The display name of the service account that is created for the cluster nodes.
- `enable_managed_prometheus` (bool, default `false`): Enables managed Prometheus.
- `enable_secret_manager_config` (bool, default `false`): Enables the Secret Manager add-on.
- `enable_secret_sync_config` (bool, default `false`): Enables the secret sync configuration.
- `disable_deletion_protection` (bool, default `false`): Disables deletion protection on the cluster.
- `maintenance_window` (object, default Saturday and Sunday from 02:00 to 08:00 UTC): The recurring maintenance window, with the attributes `start_time`, `end_time` and `recurrence`. Set to null to remove the window.

### Networking

- `create_vpc_network` (bool, default `true`): Creates a VPC network for the cluster.
- `vpc_network` (string, default `null`): The name of the VPC network. This is required when `create_vpc_network` is false.
- `subnetwork` (string, required): The subnetwork in which the cluster is created.
- `private_cluster_config` (object, default `null`): The private cluster settings, with the optional attributes `enable_private_endpoint` (default `false`), `enable_private_nodes` (default `false`) and `master_ipv4_cidr_block` (default `null`).
- `master_authorized_networks_config` (list of object, default `[]`): The networks that may reach the control plane, each with `cidr_block` and `display_name`.

### Node pools

`node_pools` (list of object, required) describes the node pools of the cluster. Each object has the following attributes.

- `name` (string, required): The name of the node pool.
- `machine_type` (string, required): The machine type of the nodes.
- `cluster_node_tags` (list of string, required): The network tags applied to the nodes.
- `min_node_count` (number, required): The minimum total node count of the autoscaler.
- `max_node_count` (number, required): The maximum total node count of the autoscaler.
- `spot_nodes` (bool, required): Uses spot VMs for the nodes.
- `node_pool_node_zones` (list of string, required): The zones in which the node pool runs.
- `enable_private_nodes` (bool, required): Creates the nodes without external IP addresses.
- `node_labels` (map of string, default `{}`): The Kubernetes labels applied to the nodes.
- `node_taints` (list of object, default `[]`): The Kubernetes taints applied to the nodes, each with `key`, `value` and `effect`. The effect must be one of NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE.
- `disk_size_gb` (number, default `null`): The boot disk size in GB. When null, the GKE default is used.
- `disk_type` (string, default `null`): The boot disk type, for example `pd-balanced` or `pd-ssd`. When null, the GKE default is used.
- `initial_node_count` (number, default `1`): The number of nodes created with the pool. A value of 0 creates the pool without nodes. Later changes to this value are ignored.
- `image_type` (string, default `"cos_containerd"`): The node image type.

## Outputs

- `service_account_email`: The email of the service account associated with the cluster.
- `service_account_id`: The id of the service account associated with the cluster.

## Tests

The tests in the `tests` directory use a mocked google provider and need no credentials. Run them with `terraform init -backend=false && terraform test`.

## Links

- [Terraform registry](https://registry.terraform.io/modules/iqz-systems/gke-cluster/google/latest)
