# AWS Provider Configuration
provider "aws" {
  region = "ap-south-1"  # Change this to your region if needed
}

# VPC Configuration
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "finance-app-vpc"
  }
}

# Public Subnet Configuration
resource "aws_subnet" "public_subnet" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet"
  }
}

# Second Public Subnet in a different Availability Zone
resource "aws_subnet" "public_subnet_2" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.3.0/24"  # Choose an unused CIDR block
  availability_zone = "ap-south-1c"  # Different availability zone
  map_public_ip_on_launch = true
  tags = {
    Name = "public-subnet-2"
  }
}


# Private Subnet Configuration
resource "aws_subnet" "private_subnet" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "private-subnet"
  }
}

# Internet Gateway for Public Subnet
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "internet-gateway"
  }
}

# Security Group for EC2 (Backend)
resource "aws_security_group" "ec2_sg" {
  name        = "ec2-security-group"
  description = "Allow HTTP, HTTPS, and SSH traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
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

# Security Group for RDS (Database)
resource "aws_security_group" "db_sg" {
  name        = "db-security-group"
  description = "Allow MySQL traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow traffic only from VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 Instance for Backend
resource "aws_instance" "backend" {
  ami           = "ami-053b12d3152c0cc71"
  instance_type = "t2.micro" 
  subnet_id     = aws_subnet.public_subnet.id
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]
  key_name      = "finance-app-keypair"
  tags = {
    Name = "backend-instance"
  }

  # Configure instance to install backend app on boot
  user_data = <<-EOF
              #!/bin/bash
              sudo apt update
              sudo apt install -y nodejs npm git
              cd /home/ubuntu
              git clone https://github.com/sanjanasukumar1/finance-tracker.git
              cd finance-tracker/backend
              npm install
              npm start
              EOF
}

# DB Subnet Group
resource "aws_db_subnet_group" "default" {
  name        = "finance-db-subnet-group"
  description = "Subnet group for RDS instance"
  subnet_ids  = [aws_subnet.public_subnet.id, aws_subnet.private_subnet.id]

  tags = {
    Name = "finance-db-subnet-group"
  }
}

# RDS MySQL Database (Free Tier)
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  storage_type         = "gp2"
  db_name              = "financeappdb"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = "db.t3.micro"  # Free-tier eligible
  username             = "admin"
  password             = "password"  # Use a secret management service for better security
  db_subnet_group_name = aws_db_subnet_group.default.name
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  multi_az             = false
  publicly_accessible  = false
  backup_retention_period = 7
  tags = {
    Name = "finance-app-db"
  }
}

# Elastic Load Balancer (ELB) for Distributing Traffic
resource "aws_lb" "app_lb" {
  name               = "finance-app-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.ec2_sg.id]
  subnets            = [
    aws_subnet.public_subnet.id,
    aws_subnet.public_subnet_2.id
  ]

  enable_deletion_protection = false
  idle_timeout    = 60
  tags = {
    Name = "finance-app-lb"
  }
}


# Load Balancer Target Group
resource "aws_lb_target_group" "app_target_group" {
  name     = "finance-app-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

# Load Balancer Listener
resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.app_lb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "fixed-response"
    fixed_response {
      status_code = 200
      content_type = "text/plain"
      message_body = "OK"
    }
  }
}

# Output the ELB DNS name for accessing the app
output "elb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

# IAM Role for EC2 Instance (if needed for AWS API calls)
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [ {
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
  })

  tags = {
    Name = "ec2-role"
  }
}

resource "aws_iam_role_policy_attachment" "ec2_role_policy_attachment" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# S3 Bucket for Terraform State (Backend)
terraform {
  backend "s3" {
    bucket         = "terraform-state-finance-app"  # Your S3 bucket name
    key            = "finance-app/terraform.tfstate"  # State file location in the bucket
    region         = "ap-south-1"
    dynamodb_table = "terraform-state-lock"  # Use DynamoDB for state locking
    encrypt        = true  # Enable encryption for security
  }
}
