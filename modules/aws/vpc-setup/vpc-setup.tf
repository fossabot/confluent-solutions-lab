# Create a VPC
resource "aws_vpc" "my_vpc" {
  # cidr_block = "10.0.0.0/16"
  cidr_block = var.vpc_cidr
  enable_dns_hostnames = true
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

# Add Route to Internet Gateway
resource "aws_route" "r_public" {
#   route_table_id         = module.vpc_setup.route_table_id
  route_table_id = aws_route_table.rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
#   gateway_id = "${module.vpc_setup.internet_gateway_id}"
}

output "public_subnet_1_id" {
  value = aws_subnet.public_subnet_1.id
}

output "public_subnet_2_id" {
  value = aws_subnet.public_subnet_2.id
}

output "public_subnet_3_id" {
  value = aws_subnet.public_subnet_3.id
}

output "vpc_id" {
  value = aws_vpc.my_vpc.id
}

output "route_table_id" {
  value = aws_route_table.rt.id
}

output "internet_gateway_id" {
  value = aws_internet_gateway.igw.id
}

output "public_subnet_ids" {
  value = [
    aws_subnet.public_subnet_1.id,
    aws_subnet.public_subnet_2.id,
    aws_subnet.public_subnet_3.id
  ]
}

output "public_subnet_azs" {
  value = [
    aws_subnet.public_subnet_1.availability_zone,
    aws_subnet.public_subnet_2.availability_zone,
    aws_subnet.public_subnet_3.availability_zone
  ]
}

output "public_subnet_az_ids" {
  value = [
    data.aws_availability_zones.available.zone_ids[0],
    data.aws_availability_zones.available.zone_ids[1],
    data.aws_availability_zones.available.zone_ids[2]
  ]
}