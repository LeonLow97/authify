variable "region" {
  description = "IMS AWS Region"
  type        = string
  default     = "ap-southeast-1"
}

variable "az1" {
  description = "Singapore Availability Zone 1"
  type        = string
  default     = "ap-southeast-1a"
}

variable "az2" {
  description = "Singapore Availability Zone 2"
  type        = string
  default     = "ap-southeast-1b"
}

variable "port_api_gateway" {
  type    = number
  default = 8080
}

variable "port_auth_service" {
  type    = number
  default = 50051
}

variable "port_postgresql" {
  type    = number
  default = 5432
}
