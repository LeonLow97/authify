# RDS Subnet Group
resource "aws_db_subnet_group" "main" {
  name        = "ims-db-subnet-group"
  description = "Subnet Group for RDS in VPC (${var.vpc_id}) Private Subnets"
  subnet_ids  = var.private_rds_subnets

  tags = {
    Name = "rds-subnet-group"
  }
}

# RDS Instance
resource "aws_db_instance" "main" {
  identifier              = var.db_config.instance_identifier
  instance_class          = var.db_config.instance_class
  engine                  = var.db_config.engine
  engine_version          = var.db_config.engine_version
  allocated_storage       = var.db_config.storage
  storage_type            = var.db_config.storage_type
  username                = var.db_config.master_username
  password                = var.db_config.master_password
  backup_retention_period = var.db_config.backup_retention_period
  parameter_group_name    = var.db_config.parameter_group_name
  db_subnet_group_name    = aws_db_subnet_group.main.name
  vpc_security_group_ids  = [var.db_sg]
  multi_az                = true
  publicly_accessible     = false # Use Bastion Host
  deletion_protection     = false
  skip_final_snapshot     = true

  tags = {
    Name = "IMS RDS Instance"
  }
}

# Insert RDS values into AWS SSM
resource "aws_ssm_parameter" "db_hostname" {
  name  = "/ims/db/hostname"
  type  = "String"
  value = split(":", aws_db_instance.main.endpoint)[0]
}

resource "aws_ssm_parameter" "db_master_username" {
  name  = "/ims/db/master-username"
  type  = "String"
  value = var.db_config.master_username
}

resource "aws_ssm_parameter" "db_master_password" {
  name  = "/ims/db/master-password"
  type  = "String"
  value = var.db_config.master_password
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/ims/db/db-name"
  type  = "String"
  value = var.db_config.db_name
}
