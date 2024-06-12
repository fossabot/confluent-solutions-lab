variable "cloud_service_provider" {
  type = string
}

variable "counfluent_cloud_region" {
  type = string
}

variable "environment_id" {
  type = string
}

variable "network_id" {
  type = string
}

variable "cluster_availability" {
  type = string
  default = "MULTI_ZONE"
}

variable "cluster_cku" {
  type = number
  default = 2
}