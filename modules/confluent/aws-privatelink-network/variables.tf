variable "vpc_region" {
  description = "The region of the AWS VPC."
  type        = string
}

variable "subnets_to_privatelink" {
  description = "A map of Zone ID to Subnet ID (i.e.: {\"use1-az1\" = \"subnet-abcdef0123456789a\", ...})"
  type        = map(string)
}

variable "environment_id" {
  type = string
}

variable "aws_account_id" {
  description = "The AWS Account ID (12 digits)"
  type        = string
}