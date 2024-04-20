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

# Create Confluent Cloud Environment
resource "confluent_environment" "demo" {
  display_name = "Environment"
  stream_governance {
    package = "ESSENTIALS"
  }
}

# Create Confluent Cloud Network
resource "confluent_network" "transit-gateway" {
  display_name     = "Transit Gateway Network"
  cloud            = "AWS"
  region           = var.counfluent_cloud_region
  cidr             = var.confluent_cloud_cidr
  connection_types = ["TRANSITGATEWAY"]
  environment {
    id = confluent_environment.demo.id
  }
}

# Transit Gateway attachment from CC
resource "confluent_transit_gateway_attachment" "aws" {
  display_name = "AWS Transit Gateway Attachment"
  aws {
    ram_resource_share_arn = aws_ram_resource_share.confluent.arn
    transit_gateway_id     = data.aws_ec2_transit_gateway.input.id
    routes                 = var.routes
  }
  environment {
    id = confluent_environment.demo.id
  }
  network {
    id = confluent_network.transit-gateway.id
  }
}

# Kafka Cluster
resource "confluent_kafka_cluster" "dedicated" {
  display_name = "Cluster"
  availability = "MULTI_ZONE"
  cloud        = confluent_network.transit-gateway.cloud
  region       = confluent_network.transit-gateway.region
  dedicated {
    cku = 2
  }
  environment {
    id = confluent_environment.demo.id
  }
  network {
    id = confluent_network.transit-gateway.id
  }
}

# Create a Transit Gateway Connection to Confluent Cloud on AWS
provider "aws" {
  region = var.vpc_region
  default_tags {
    tags = {
      owner_email = var.resource_identifier
      }
  }
}

# Sharing Transit Gateway with Confluent via Resource Access Manager (RAM) Resource Share
resource "aws_ram_resource_share" "confluent" {
  name                      = "resource-share-with-confluent"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "confluent" {
  principal          = confluent_network.transit-gateway.aws[0].account
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

data "aws_ec2_transit_gateway" "input" {
  id = var.transit_gateway_id
}

resource "aws_ram_resource_association" "example" {
  resource_arn       = data.aws_ec2_transit_gateway.input.arn
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

# Accepter's side of the connection.
data "aws_ec2_transit_gateway_vpc_attachment" "accepter" {
  id = confluent_transit_gateway_attachment.aws.aws[0].transit_gateway_attachment_id
}

# Accept Transit Gateway Attachment from Confluent
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepter" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_vpc_attachment.accepter.id
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  # cidr_block = "10.0.0.0/16"
  cidr_block = var.vpc_cidr

  tags = {
    Name = "VPC"
  }
}

# Declare Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  subnet_1 = cidrsubnet(var.vpc_cidr, 4, 0)  # First /20 subnet
  subnet_2 = cidrsubnet(var.vpc_cidr, 4, 1)  # Second /20 subnet
  subnet_3 = cidrsubnet(var.vpc_cidr, 4, 2)  # Third /20 subnet
}

# Create subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  # cidr_block = "10.0.16.0/20"
  cidr_block = local.subnet_1
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_1"
  }
}

# Create subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  # cidr_block = "10.0.32.0/20"
  cidr_block = local.subnet_2
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "public_subnet_2"
  }
}

# Create subnet 3
resource "aws_subnet" "public_subnet_3" {
  vpc_id     = aws_vpc.my_vpc.id
  # cidr_block = "10.0.48.0/20"
  cidr_block = local.subnet_3
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[2]
  tags = {
    Name = "public_subnet_3"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "igw"
  }
}

# Route Table
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.my_vpc.id
  tags = {
    Name = "rt"
  }
}

# Associate Route Table to Subnets
resource "aws_route_table_association" "public_subnet_1" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "public_subnet_2" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "public_subnet_3" {
  subnet_id      = aws_subnet.public_subnet_3.id
  route_table_id = aws_route_table.rt.id
}

# Create Transit Gateway Attachment for the user's VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
    aws_subnet.public_subnet_3.id
  ]
  transit_gateway_id = data.aws_ec2_transit_gateway.input.id
  vpc_id             = aws_vpc.my_vpc.id
}

# Add route to Transit Gateway
resource "aws_route" "r" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = confluent_network.transit-gateway.cidr
  transit_gateway_id     = data.aws_ec2_transit_gateway.input.id
}

# Add Route to Internet Gateway
resource "aws_route" "r_public" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.igw.id}"
}

# Create IAM Role
resource "aws_iam_role" "ssm_role" {
  name = "SSMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      },
    ]
  })
}

# Attach SSM policy to IAM Role
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# AWS Instance Profile
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "SSMInstanceProfile"
  role = aws_iam_role.ssm_role.name
}

# Create a security group for EC2 Instance
resource "aws_security_group" "security_group" {
  name        = "security_group"
  description = "Security Group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    description = "Allow 9092 for all"
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow 22 for all"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow 443 for all"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create EC2 Instance
resource "aws_instance" "amazon_linux" {
  ami                     = "ami-09b90e09742640522"
  instance_type           = "t2.micro"
  vpc_security_group_ids  = [aws_security_group.security_group.id]
  subnet_id               = aws_subnet.public_subnet_1.id
  associate_public_ip_address = true
  user_data = <<-EOF
              #!/bin/bash
              sudo yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
              EOF
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.id
  tags = {
    Name = "EC2 Server"
  }
}