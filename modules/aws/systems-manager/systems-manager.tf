resource "random_pet" "ssm_suffix" {
  length = 5
}

# Create IAM Role
resource "aws_iam_role" "ssm_role" {
  name = "SSMRole-${random_pet.ssm_suffix.id}"

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
  name = "SSMInstanceProfile-${random_pet.ssm_suffix.id}"
  role = aws_iam_role.ssm_role.name
}

# Create a security group for EC2 Instance
resource "aws_security_group" "security_group" {
  name        = "security_group"
  description = "Security Group"
  vpc_id      = var.vpc_id

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
  subnet_id               = var.public_subnet_1_id
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

output amazon_linux_id {
  value = aws_instance.amazon_linux.id
}
  