# Sharing Transit Gateway with Confluent via Resource Access Manager (RAM) Resource Share
resource "aws_ram_resource_share" "confluent" {
  name                      = "resource-share-with-confluent"
  allow_external_principals = true
}

resource "aws_ram_principal_association" "confluent" {
  principal          = var.principal
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
  id = var.acceptor_id
}

# Accept Transit Gateway Attachment from Confluent
resource "aws_ec2_transit_gateway_vpc_attachment_accepter" "accepter" {
  transit_gateway_attachment_id = data.aws_ec2_transit_gateway_vpc_attachment.accepter.id
}

# Create Transit Gateway Attachment for the user's VPC
resource "aws_ec2_transit_gateway_vpc_attachment" "attachment" {
  subnet_ids = [
    var.public_subnet_1_id,
    var.public_subnet_2_id,
    var.public_subnet_3_id
  ]
  transit_gateway_id = data.aws_ec2_transit_gateway.input.id
  vpc_id             = var.vpc_id
}

# Add route to Transit Gateway
resource "aws_route" "r" {
  route_table_id         = var.route_table_id
  destination_cidr_block = var.confluent_cloud_cidr
  transit_gateway_id     = data.aws_ec2_transit_gateway.input.id
}

output "ram_resource_share_arn" {
  value = aws_ram_resource_share.confluent.arn
}