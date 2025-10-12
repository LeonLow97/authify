variable "api_gateway_key_name_az1" {
  type    = string
  default = "IMS_API_GATEWAY_KEY_PAIR_AZ1"
}
variable "api_gateway_key_name_az2" {
  type    = string
  default = "IMS_API_GATEWAY_KEY_PAIR_AZ2"
}
variable "auth_service_key_name_az1" {
  type    = string
  default = "IMS_AUTH_SERVICE_KEY_PAIR_AZ1"
}
variable "auth_service_key_name_az2" {
  type    = string
  default = "IMS_AUTH_SERVICE_KEY_PAIR_AZ2"
}
variable "bastion_key_name_az1" {
  type    = string
  default = "IMS_BASTION_AZ1"
}
variable "bastion_key_name_az2" {
  type    = string
  default = "IMS_BASTION_AZ2"
}

variable "bastion_sg" {
  type = string
}
variable "auth_sg" {
  type = string
}
variable "api_gateway_sg" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}
variable "private_subnets" {
  type = list(string)
}

variable "ec2_iam_role" {
  type    = string
  default = "IMS-EC2-Role"
}
variable "ec2_iam_bastion_role" {
  type    = string
  default = "IMS-Bastion-SSM"
}

variable "db_endpoint" {
  type = string
}
