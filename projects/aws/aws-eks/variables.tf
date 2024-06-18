variable "aws_access_key" {
  description = "AWS API Key"
  type        = string
}

variable "aws_secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "AWS Region"
  type        = string
}

variable "disk_size" {
  description = "EC2 instance disk size"
  type        = number
}

variable "instance_types" {
  description = "EC2 instance type"
  type        = list(string)
}