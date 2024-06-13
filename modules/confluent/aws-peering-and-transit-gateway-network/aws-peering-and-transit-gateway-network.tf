terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.71.0"
    }
  }
}

resource "confluent_network" "network" {
  display_name     = "Network"
  cloud            = var.cloud_service_provider
  region           = var.counfluent_cloud_region
  cidr             = var.confluent_cloud_cidr
  connection_types = var.network_type
  environment {
    id = var.environment_id
  }
}

output "network_id" {
  value = confluent_network.network.id
}

output "confluent_cloud_aws_account" {
  value = confluent_network.network.aws[0].account
}

output "confluent_vpc_id" {
  value = confluent_network.network.aws[0].vpc
}