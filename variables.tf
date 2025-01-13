variable "cluster_region" {
  type        = string
  description = "The region where the cluster master has to be created."
}

variable "cluster_node_zones" {
  type        = list(string)
  description = "A list of zones for the cluster nodes."
}

variable "cluster_name" {
  type        = string
  description = "The name of the cluster to be created."
}

variable "cluster_description" {
  type        = string
  default     = ""
  description = "The description to be associated with the cluster."
}

variable "node_pools" {
  type = list(object({
    name                 = string
    machine_type         = string
    cluster_node_tags    = list(string)
    min_node_count       = number
    max_node_count       = number
    spot_nodes           = bool
    node_pool_node_zones = list(string)
    enable_private_nodes = bool
  }))
  description = "A list of objects describing the node pools to be associated with the cluster."
}

variable "node_service_account_name" {
  type        = string
  description = "The display name of the service account that will be created for the cluster."
}

variable "enable_managed_prometheus" {
  type        = bool
  default     = false
  description = "Set true to enable managed prometheus. Defaults to false."
}

variable "disable_deletion_protection" {
  type        = bool
  default     = false
  description = "Set true to disable disable deletion protection. Defaults to false."
}

variable "create_vpc_network" {
  type        = bool
  default     = true
  description = "Set true to create a vpc for gke. Defaults to true."
}

variable "vpc_network" {
  type        = string
  description = "The vpc name where the cluster master has to be created."
  default = ""
 
}
