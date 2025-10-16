provider "aws" {
  region = "ap-south-1"
}

# Generate unique suffix for naming
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket to store the app (private)
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "capstone-task3-app-${random_id.suffix.hex}"
  force_destroy = true   # allows deletion even if non-empty
}

# Upload index.html to S3 (private)
resource "aws_s3_object" "app_file" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "index.html"
  source = "index.html"
}

# Security group with unique name
resource "aws_security_group" "allow_http" {
  name        = "allow_http_${random_id.suffix.hex}"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

    # Allow SSH
  ingress {
    description = "SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # safer: replace with your IP only
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Get latest Amazon Linux 2 AMI for the region
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2 instance
resource "aws_instance" "app_server" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_http.name]

  # User Data to fetch index.html from S3 and start server
  user_data = <<-EOF
              #!/bin/bash
              yum install -y python3 awscli
              mkdir -p /home/ec2-user/webapp
              aws s3 cp s3://${aws_s3_bucket.app_bucket.bucket}/index.html /home/ec2-user/webapp/index.html
              nohup python3 -m http.server 80 --directory /home/ec2-user/webapp &
              EOF

  tags = {
    Name = "capstone-task3-ec2"
  }
}

# Outputs
output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "s3_bucket" {
  value = aws_s3_bucket.app_bucket.bucket
}