terraform {
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.71.0"
    }
  }
}

# Create Confluent Cloud Environment
resource "confluent_environment" "demo" {
  display_name = "Environment"
  stream_governance {
    package = "ESSENTIALS"
  }
}

output "environment_id" {
  value = confluent_environment.demo.id
}