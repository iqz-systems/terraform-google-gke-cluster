variable "project_id" {
  type        = string
  description = "The id of the project where the cluster has to be created."
}

variable "project_region" {
  type        = string
  description = "The region where the resources will be created."
}

variable "project_zone" {
  type        = list(string)
  description = "The zone where the resources will be created."
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
    name              = string
    machine_type      = string
    cluster_node_tags = list(string)
  }))
}

variable "machine_type" {
  type        = string
  description = "The machine type to be used in the cluster."
}

variable "node_service_account_name" {
  type        = string
  description = "The display name of the service account that will be created for the cluster."
}
