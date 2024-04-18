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

resource "confluent_environment" "staging" {
  display_name = "Demo"
  stream_governance {
    package = "ESSENTIALS"
  }
}


resource "confluent_network" "peering" {
  display_name     = "Peering Network"
  cloud            = "AWS"
  region           = var.region
  cidr             = var.cidr
  connection_types = ["PEERING"]
  environment {
    id = confluent_environment.staging.id
  }
}

resource "confluent_peering" "aws" {
  display_name = "AWS Peering"
  aws {
    account         = var.aws_account_id
    vpc             = aws_vpc.my_vpc.id
    routes          = [aws_vpc.my_vpc.cidr_block]
    customer_region = var.customer_region
  }
  environment {
    id = confluent_environment.staging.id
  }
  network {
    id = confluent_network.peering.id
  }
}

resource "confluent_kafka_cluster" "dedicated" {
  display_name = "Demo"
  availability = "SINGLE_ZONE"
  cloud        = confluent_network.peering.cloud
  region       = confluent_network.peering.region
  dedicated {
    cku = 1
  }
  environment {
    id = confluent_environment.staging.id
  }
  network {
    id = confluent_network.peering.id
  }
}

# Create a VPC Peering Connection to Confluent Cloud on AWS
provider "aws" {
  region = var.customer_region
  default_tags {
    tags = {
      owner_email = var.resource_identifier
      }
  }
}

# Create a VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "sj_vpc"
  }
}

# Declare Availability Zones
data "aws_availability_zones" "available" {
  state = "available"
}

# Create subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.16.0/20"
  availability_zone = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "public_subnet_1"
  }
}

# Create subnet 2
resource "aws_subnet" "public_subnet_2" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.32.0/20"
  map_public_ip_on_launch = true
  availability_zone = data.aws_availability_zones.available.names[1]
  tags = {
    Name = "public_subnet_2"
  }
}

# Create subnet 3
resource "aws_subnet" "public_subnet_3" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.48.0/20"
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

# Associate Route Table
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


# Accepter's side of the connection.
data "aws_vpc_peering_connection" "accepter" {
  vpc_id      = confluent_network.peering.aws[0].vpc
  peer_vpc_id = confluent_peering.aws.aws[0].vpc
}

resource "aws_vpc_peering_connection_accepter" "peer" {
  vpc_peering_connection_id = data.aws_vpc_peering_connection.accepter.id
  auto_accept               = true
}

# Find the routing table
data "aws_route_tables" "rts" {
  vpc_id = aws_vpc.my_vpc.id
}

resource "aws_route" "r" {
#   for_each                  = toset(data.aws_route_tables.rts.ids)
  route_table_id            = aws_route_table.rt.id
  destination_cidr_block    = confluent_network.peering.cidr
  vpc_peering_connection_id = data.aws_vpc_peering_connection.accepter.id
}

resource "aws_route" "r_public" {
  route_table_id         = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = "${aws_internet_gateway.igw.id}"
}

resource "aws_security_group" "proxy_security_group" {
  name        = "proxy_security_group"
  description = "Security Group associated with the subnet created for the proxy server"
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


### Migration to TGW

# Step 1: Attach your VPC to the TGW

data "aws_ec2_transit_gateway" "input" {
  id = var.transit_gateway_id
}

resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
    aws_subnet.public_subnet_3.id
  ]
  transit_gateway_id = data.aws_ec2_transit_gateway.input.id
  vpc_id             = aws_vpc.my_vpc.id
}

# Step 2: Share TGW with Confluent Cloud

resource "aws_ram_resource_share" "confluent" {
  name                      = "resource-share-with-confluent"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "confluent" {
  principal          = confluent_network.peering.aws[0].account
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

resource "aws_ram_resource_association" "example" {
  resource_arn       = data.aws_ec2_transit_gateway.input.arn
  resource_share_arn = aws_ram_resource_share.confluent.arn
}

# Step 3: Create TGW Attachment on CC

resource "confluent_transit_gateway_attachment" "aws" {
  display_name = "AWS Transit Gateway Attachment"
  aws {
    ram_resource_share_arn = aws_ram_resource_share.confluent.arn
    transit_gateway_id     = data.aws_ec2_transit_gateway.input.id
    routes                 = ["10.0.0.0/15"]
  }
  environment {
    id = confluent_environment.staging.id
  }
  network {
    id = confluent_network.peering.id
  }
}

# Step 4: Accept TGW attachment on AWS

data "aws_ec2_transit_gateway_vpc_attachment" "accepter" {
  id = confluent_transit_gateway_attachment.aws.aws[0].transit_gateway_attachment_id
}

resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepter" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_vpc_attachment.accepter.id
}

# Step 5: Change route table to send traffic to TGW instead of Peering (manual step in AWS). Make sure all clients are still working.

# Step 6: Delete the peering connection on Confluent Cloud (manual step in CC). Once this is done, confirm that the peering has also been deleted on AWS automatically.

# Step 7: Work with Confluent support to swap the broader CIDR with the narrow one. This needs to be done in a specific way to make sure there is no disruption.