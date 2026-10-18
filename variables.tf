variable "project_id" {
  type        = string
  default     = null
  description = "The project in which the resources are created. When null, the project of the google provider configuration is used."
}

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
    node_labels          = optional(map(string), {})
    node_taints = optional(list(object({
      key    = string
      value  = string
      effect = string
    })), [])
    disk_size_gb       = optional(number, null)
    disk_type          = optional(string, null)
    initial_node_count = optional(number, 1)
    image_type         = optional(string, "cos_containerd")
  }))
  description = "A list of objects describing the node pools to be associated with the cluster."

  validation {
    condition     = alltrue(flatten([for pool in var.node_pools : [for taint in pool.node_taints : contains(["NO_SCHEDULE", "PREFER_NO_SCHEDULE", "NO_EXECUTE"], taint.effect)]]))
    error_message = "Each node taint effect must be one of NO_SCHEDULE, PREFER_NO_SCHEDULE or NO_EXECUTE."
  }
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

variable "enable_secret_manager_config" {
  type        = bool
  default     = false
  description = "Set true to enable secret manager config. Defaults to false."
}

variable "enable_secret_sync_config" {
  type        = bool
  default     = false
  description = "Set true to enable secret sync config. Defaults to false."
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
  default     = null

}

variable "subnetwork" {
  type = string

}

variable "private_cluster_config" {
  type = object({
    enable_private_endpoint = optional(bool, false)
    enable_private_nodes    = optional(bool, false)
    master_ipv4_cidr_block  = optional(string, null)
  })
  default = null
}

variable "master_authorized_networks_config" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "maintenance_window" {
  description = "Configuration for the maintenance window."
  type = object({
    start_time = string
    end_time   = string
    recurrence = string
  })
  default = {
    start_time = "2025-02-28T02:00:00Z" # 2:00 AM UTC
    end_time   = "2025-02-28T08:00:00Z" # 8:00 AM UTC
    recurrence = "FREQ=WEEKLY;BYDAY=SA,SU"
  }
}

variable "release_channel" {
  type        = string
  default     = "REGULAR"
  description = "The GKE release channel of the cluster. Defaults to REGULAR."

  validation {
    condition     = contains(["UNSPECIFIED", "RAPID", "REGULAR", "STABLE", "EXTENDED"], var.release_channel)
    error_message = "The release channel must be one of UNSPECIFIED, RAPID, REGULAR, STABLE or EXTENDED."
  }
}
