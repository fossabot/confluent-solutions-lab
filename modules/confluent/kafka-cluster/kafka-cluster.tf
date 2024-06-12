terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.71.0"
    }
  }
}

resource "confluent_kafka_cluster" "cluster" {
  display_name = "Cluster"
  availability = var.cluster_availability
  cloud        = var.cloud_service_provider
  region       = var.counfluent_cloud_region
  dedicated {
    cku = var.cluster_cku
  }
  environment {
    id = var.environment_id
  }
  network {
    id = var.network_id
  }
}

output "bootstrap_endpoint" {
  value = confluent_kafka_cluster.cluster.bootstrap_endpoint
}