# API Gateway Key Pairs
resource "aws_key_pair" "api_gateway_az1" {
  key_name   = var.api_gateway_key_name_az1
  public_key = file("${path.module}/.ssh/${var.api_gateway_key_name_az1}.pub")
}

resource "aws_key_pair" "api_gateway_az2" {
  key_name   = var.api_gateway_key_name_az2
  public_key = file("${path.module}/.ssh/${var.api_gateway_key_name_az2}.pub")
}

# Auth Microservice Key Pairs
resource "aws_key_pair" "auth_service_az1" {
  key_name   = var.auth_service_key_name_az1
  public_key = file("${path.module}/.ssh/${var.auth_service_key_name_az1}.pub")
}

resource "aws_key_pair" "auth_service_az2" {
  key_name   = var.auth_service_key_name_az2
  public_key = file("${path.module}/.ssh/${var.auth_service_key_name_az2}.pub")
}

# Bastion Host Key Pairs
resource "aws_key_pair" "bastion_az1" {
  key_name   = var.bastion_key_name_az1
  public_key = file("${path.module}/.ssh/${var.bastion_key_name_az1}.pub")
}

resource "aws_key_pair" "bastion_az2" {
  key_name   = var.bastion_key_name_az2
  public_key = file("${path.module}/.ssh/${var.bastion_key_name_az2}.pub")
}

# Bastion Host EC2
resource "aws_instance" "bastion_az1" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t2.nano"
  key_name                    = var.bastion_key_name_az1
  security_groups             = [var.bastion_sg]
  associate_public_ip_address = true
  iam_instance_profile        = var.ec2_iam_bastion_role
  user_data                   = file("../../scripts/bastion-script.sh")
  subnet_id                   = var.public_subnets[0]

  tags = {
    Name = "bastion-host-az1"
  }
}
resource "aws_instance" "bastion_az2" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t2.nano"
  key_name                    = var.bastion_key_name_az2
  security_groups             = [var.bastion_sg]
  associate_public_ip_address = true
  iam_instance_profile        = var.ec2_iam_bastion_role
  user_data                   = file("../../scripts/bastion-script.sh")
  subnet_id                   = var.public_subnets[1]

  tags = {
    Name = "bastion-host-az2"
  }
}

resource "aws_instance" "auth_service_az1" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t3.micro"
  key_name                    = var.auth_service_key_name_az1
  security_groups             = [var.auth_sg]
  associate_public_ip_address = false
  iam_instance_profile        = var.ec2_iam_role
  user_data                   = file("../../scripts/authentication-script.sh")
  subnet_id                   = var.private_subnets[0]

  tags = {
    Name = "auth-service-az1"
  }
}

resource "aws_instance" "auth_service_az2" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t3.micro"
  key_name                    = var.auth_service_key_name_az2
  security_groups             = [var.auth_sg]
  associate_public_ip_address = false
  iam_instance_profile        = var.ec2_iam_role
  user_data                   = file("../../scripts/authentication-script.sh")
  subnet_id                   = var.private_subnets[1]

  tags = {
    Name = "auth-service-az2"
  }
}

resource "aws_instance" "api_gateway_az1" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t3.micro"
  key_name                    = var.api_gateway_key_name_az1
  security_groups             = [var.api_gateway_sg]
  associate_public_ip_address = false
  iam_instance_profile        = var.ec2_iam_role
  user_data = templatefile("../../scripts/api-gateway-script.sh.tpl", {
    auth_service_ip = aws_instance.auth_service_az1.private_ip
  })
  subnet_id = var.private_subnets[0]

  depends_on = [aws_instance.auth_service_az1]

  tags = {
    Name = "api-gateway-az1"
  }
}

resource "aws_instance" "api_gateway_az2" {
  ami                         = "ami-065a492fef70f84b1"
  instance_type               = "t3.micro"
  key_name                    = var.api_gateway_key_name_az2
  security_groups             = [var.api_gateway_sg]
  associate_public_ip_address = false
  iam_instance_profile        = var.ec2_iam_role
  subnet_id                   = var.private_subnets[1]

  user_data = templatefile("../../scripts/api-gateway-script.sh.tpl", {
    auth_service_ip = aws_instance.auth_service_az2.private_ip
  })

  depends_on = [aws_instance.auth_service_az2]

  tags = {
    Name = "api-gateway-az2"
  }
}
