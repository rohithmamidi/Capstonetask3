provider "aws" {
  region = "ap-south-1"
}

# Generate unique suffix for S3 bucket
resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket to store the app
resource "aws_s3_bucket" "app_bucket" {
  bucket = "capstone-task3-app-${random_id.suffix.hex}"
  acl    = "public-read"
}

# Upload index.html to S3
resource "aws_s3_bucket_object" "app_file" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "index.html"
  source = "index.html"
  acl    = "public-read"
}

# Security group to allow HTTP
resource "aws_security_group" "allow_http" {
  name        = "allow_http"
  description = "Allow HTTP traffic"

  ingress {
    from_port   = 80
    to_port     = 80
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

# EC2 instance
resource "aws_instance" "app_server" {
  ami           = "ami-0c02fb55956c7d316" # Amazon Linux 2
  instance_type = "t2.micro"
  security_groups = [aws_security_group.allow_http.name]

  # User Data to fetch app from S3 and start Python HTTP server
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

# Output EC2 public IP
output "ec2_public_ip" {
  value = aws_instance.app_server.public_ip
}

# Output S3 bucket name
output "s3_bucket" {
  value = aws_s3_bucket.app_bucket.bucket
}