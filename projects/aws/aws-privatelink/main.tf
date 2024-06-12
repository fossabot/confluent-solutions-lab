terraform {
  required_version = ">= 0.14.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.17.0"
    }
    confluent = {
      source  = "confluentinc/confluent"
      version = "1.71.0"
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

locals {
  subnets_to_privatelink = {
    for idx in range(0, length(module.vpc_setup.public_subnet_ids)) :
    module.vpc_setup.public_subnet_az_ids[idx] => module.vpc_setup.public_subnet_ids[idx]
  }

  az_names = {
    for idx in range(0, length(module.vpc_setup.public_subnet_azs)) :
    module.vpc_setup.public_subnet_az_ids[idx] => module.vpc_setup.public_subnet_azs[idx]
  }
}

# Create Confluent Cloud Network
module "network" {
  source = "../../../modules/confluent/aws-privatelink-network"
  aws_account_id = var.aws_account_id
  subnets_to_privatelink = local.subnets_to_privatelink
  vpc_region = var.vpc_region
  environment_id = module.environment.environment_id
}

module "cluster" {
  source = "../../../modules/confluent/kafka-cluster"
  cloud_service_provider = var.cloud_service_provider
  counfluent_cloud_region = var.counfluent_cloud_region
  environment_id = module.environment.environment_id
  network_id = module.network.network_id
  
  depends_on = [
    module.network
  ]
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

locals {
  hosted_zone = length(regexall(".glb", module.cluster.bootstrap_endpoint)) > 0 ? replace(regex("^[^.]+-([0-9a-zA-Z]+[.].*):[0-9]+$", module.cluster.bootstrap_endpoint)[0], "glb.", "") : regex("[.]([0-9a-zA-Z]+[.].*):[0-9]+$", module.cluster.bootstrap_endpoint)[0]
}

data "aws_vpc" "privatelink" {
  id = module.vpc_setup.vpc_id
}

data "aws_availability_zone" "privatelink" {
  for_each = local.subnets_to_privatelink
  zone_id  = each.key
}

locals {
  bootstrap_prefix = split(".", module.cluster.bootstrap_endpoint)[0]
}

resource "aws_security_group" "privatelink" {
  # Ensure that SG is unique, so that this module can be used multiple times within a single VPC
  name        = "ccloud-privatelink_${local.bootstrap_prefix}_${module.vpc_setup.vpc_id}"
  description = "Confluent Cloud Private Link minimal security group for ${module.cluster.bootstrap_endpoint} in ${module.vpc_setup.vpc_id}"
  vpc_id      = data.aws_vpc.privatelink.id

  ingress {
    # only necessary if redirect support from http/https is desired
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = [data.aws_vpc.privatelink.cidr_block]
  }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_endpoint" "privatelink" {
  vpc_id            = data.aws_vpc.privatelink.id
  service_name      = module.network.service_name
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.privatelink.id,
  ]

  subnet_ids          = [for zone, subnet_id in local.subnets_to_privatelink : subnet_id]
  private_dns_enabled = false

  depends_on = [
    module.network.confluent_private_link_access,
  ]
}

resource "aws_route53_zone" "privatelink" {
  name = local.hosted_zone

  vpc {
    vpc_id = data.aws_vpc.privatelink.id
  }
}

resource "aws_route53_record" "privatelink" {
  count   = length(local.subnets_to_privatelink) == 1 ? 0 : 1
  zone_id = aws_route53_zone.privatelink.zone_id
  name    = "*.${aws_route53_zone.privatelink.name}"
  type    = "CNAME"
  ttl     = "60"
  records = [
    aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"]
  ]
}

locals {
  endpoint_prefix = split(".", aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"])[0]
}

resource "aws_route53_record" "privatelink-zonal" {
  for_each = local.subnets_to_privatelink

  zone_id = aws_route53_zone.privatelink.zone_id
  name    = length(local.subnets_to_privatelink) == 1 ? "*" : "*.${each.key}"
  type    = "CNAME"
  ttl     = "60"
  records = [
    format("%s-%s%s",
      local.endpoint_prefix,
      local.az_names[each.key],
      replace(aws_vpc_endpoint.privatelink.dns_entry[0]["dns_name"], local.endpoint_prefix, "")
    )
  ]
}