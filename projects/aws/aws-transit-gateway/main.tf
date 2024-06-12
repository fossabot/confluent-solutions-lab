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
  source = "../../../modules/confluent/aws-transit-gateway-network"
  counfluent_cloud_region = var.counfluent_cloud_region
  confluent_cloud_cidr = var.confluent_cloud_cidr
  network_type = ["TRANSITGATEWAY"]
  environment_id = module.environment.environment_id
  cloud_service_provider = var.cloud_service_provider
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

# Transit Gateway attachment from CC
resource "confluent_transit_gateway_attachment" "aws" {
  display_name = "AWS Transit Gateway Attachment"
  aws {
    # ram_resource_share_arn = aws_ram_resource_share.confluent.arn
    ram_resource_share_arn = module.transit_gateway.ram_resource_share_arn
    # transit_gateway_id     = data.aws_ec2_transit_gateway.input.id
    transit_gateway_id = var.transit_gateway_id
    routes                 = var.routes
  }
  environment {
    id = module.environment.environment_id
  }
  network {
    id = module.network.network_id
  }
}

module "transit_gateway" {
  source = "../../../modules/aws/transit-gateway"
  confluent_cloud_cidr = var.confluent_cloud_cidr
  transit_gateway_id = var.transit_gateway_id
  vpc_id = module.vpc_setup.vpc_id
  public_subnet_1_id = module.vpc_setup.public_subnet_1_id
  public_subnet_2_id = module.vpc_setup.public_subnet_2_id
  public_subnet_3_id = module.vpc_setup.public_subnet_3_id
  route_table_id = module.vpc_setup.route_table_id
  principal = module.network.confluent_cloud_aws_account
  acceptor_id = confluent_transit_gateway_attachment.aws.aws[0].transit_gateway_attachment_id
}
