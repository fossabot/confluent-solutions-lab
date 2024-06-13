terraform {
  required_version = ">= 0.14.0"
  required_providers {
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.71.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.17.0"
    }
  }
}

provider "confluent" {
  cloud_api_key    = var.confluent_cloud_api_key
  cloud_api_secret = var.confluent_cloud_api_secret
}

provider "aws" {
  region = var.vpc_region
  default_tags {
    tags = {
      owner_email = var.resource_identifier
      }
  }
}

module "environment" {
  source = "../../../modules/confluent/environment"
}

# Create Confluent Cloud Network
module "network" {
  source = "../../../modules/confluent/aws-peering-and-transit-gateway-network"
  counfluent_cloud_region = var.counfluent_cloud_region
  confluent_cloud_cidr = var.confluent_cloud_cidr
  network_type = ["PEERING"]
  environment_id = module.environment.environment_id
  cloud_service_provider = var.cloud_service_provider
}

resource "confluent_peering" "aws" {
  display_name = "AWS Peering"
  aws {
    account         = var.aws_account_id
    vpc             = module.vpc_setup.vpc_id
    routes          = [var.vpc_cidr]
    customer_region = var.vpc_region
  }
  environment {
    id = module.environment.environment_id
  }
  network {
    id = module.network.network_id
  }
}

module "cluster" {
  source = "../../../modules/confluent/kafka-cluster"
  cloud_service_provider = var.cloud_service_provider
  counfluent_cloud_region = var.counfluent_cloud_region
  environment_id = module.environment.environment_id
  network_id = module.network.network_id
}

module "vpc_setup" {
  source = "../../../modules/aws/vpc-setup"
  vpc_cidr = var.vpc_cidr
}

module "systems_manager" {
  source = "../../../modules/aws/systems-manager"
  vpc_id = module.vpc_setup.vpc_id
  public_subnet_1_id = module.vpc_setup.public_subnet_1_id
}

# Accepter's side of the connection.
data "aws_vpc_peering_connection" "accepter" {
  vpc_id = module.network.confluent_vpc_id
  peer_vpc_id = confluent_peering.aws.aws[0].vpc
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = data.aws_vpc_peering_connection.accepter.id
  auto_accept               = true
}

# Find the routing table
data "aws_route_tables" "rts" {
  vpc_id = module.vpc_setup.vpc_id
}

resource "aws_route" "r" {
  route_table_id            = module.vpc_setup.route_table_id
  destination_cidr_block    = var.confluent_cloud_cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.accepter.id
}
