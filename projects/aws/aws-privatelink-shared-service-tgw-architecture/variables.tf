variable "confluent_cloud_api_key" {
  description = "Confluent Cloud API Key (also referred as Cloud API ID)."
  type        = string
}

variable "confluent_cloud_api_secret" {
  description = "Confluent Cloud API Secret." 
  type        = string
  sensitive   = true
}

variable "vpc_region" {
  description = "The region of the AWS VPC."
  type        = string

}

variable "resource_identifier" {
    description = "Label to tag AWS resources"
    type = string
}

variable "counfluent_cloud_region" {
  description = "The region of Confluent Cloud Network."
  type        = string
}

variable "confluent_cloud_cidr" {
  description = "The CIDR of Confluent Cloud Network."
  type        = string
}

variable "cloud_service_provider" {
  type = string
}

variable "aws_account_id" {
  description = "The AWS Account ID of the VPC owner (12 digits)."
  type        = string
}

variable "vpc_cidr" {
  description = "A /16 VPC CIDR of the AWS VPC"
  type        = string
}

variable "transit_gateway_id" {
  type = string
}

variable "vpc_cidr_application" {
  description = "A /16 VPC CIDR of the AWS VPC"
  type        = string
}