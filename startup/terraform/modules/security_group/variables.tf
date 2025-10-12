variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "port_api_gateway" {
  type = number
  default = 8080
}

variable "port_auth_service" {
  type = number
  default = 50051
}

variable "port_postgresql" {
  type = number
  default = 5432
}

variable "public_ip" {
  type = string
}
