variable "private_rds_subnets" {
  type        = list(string)
  description = "Private Subnets created in VPC in different AZs"
}

variable "vpc_id" {
  type = string
}

variable "db_config" {
  type = object({
    instance_identifier     = string
    instance_class          = string
    engine                  = string
    engine_version          = string
    storage                 = number
    storage_type            = string
    master_username         = string
    master_password         = string
    backup_retention_period = number
    parameter_group_name    = string
    db_name                 = string
  })

  default = {
    subnet_group_name       = "ims-db-subnet-group"
    instance_identifier     = "authentication-postgres"
    instance_class          = "db.t3.micro"
    engine                  = "postgres"
    engine_version          = "15.8"
    storage                 = 5
    storage_type            = "gp2"
    master_username         = "authentication_postgres"
    master_password         = "verysecurepassword"
    backup_retention_period = 0
    parameter_group_name    = "authentication-ec2"
    db_name                 = "imsdb"
  }
}

variable "db_sg" {
  type        = string
  description = "Database Security Group"
}
