provider "aws" {
  region = "ap-south-1"
}

resource "random_id" "suffix" {
  byte_length = 4
}

# S3 bucket without ACL
resource "aws_s3_bucket" "app_bucket" {
  bucket        = "capstone-task3-app-${random_id.suffix.hex}"
  force_destroy = true   # allows deletion even if non-empty
}

# Upload index.html and make it public
resource "aws_s3_object" "app_file" {
  bucket = aws_s3_bucket.app_bucket.id
  key    = "index.html"
  source = "index.html"
  acl    = "public-read"  # only on the object
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