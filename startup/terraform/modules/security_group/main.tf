# Create Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "ALB-SG"
  description = "Security group for ALB"
  vpc_id      = var.vpc_id

  # HTTP
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Add outbound rule to allow all traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for API Gateway
resource "aws_security_group" "api_gateway_sg" {
  name        = "API-Gateway-SG"
  description = "Security group for API Gateway"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = var.port_api_gateway
    to_port         = var.port_api_gateway
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  # Add outbound rule to allow all traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for Auth Microservice
resource "aws_security_group" "auth_sg" {
  name        = "Auth-Service-SG"
  description = "Security group for authentication microservice"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  ingress {
    from_port       = var.port_auth_service
    to_port         = var.port_auth_service
    protocol        = "tcp"
    security_groups = [aws_security_group.api_gateway_sg.id]
  }

  # Add outbound rule to allow all traffic to any destination
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # All protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for Bastion Host
resource "aws_security_group" "bastion_sg" {
  name        = "Bastion-SG"
  description = "Security group for Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.public_ip]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # -1 means all protocols
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Create Security Group for RDS Instance
resource "aws_security_group" "db_sg" {
  name        = "DB-SG"
  description = "Security group for RDS Instance"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.3.0/24"] # Private Subnet of EC2 instance in AZ1
  }

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.4.0/24"] # Private Subnet of EC2 instance in AZ2
  }

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id] # For creating tables and granting privileges
  }
}
