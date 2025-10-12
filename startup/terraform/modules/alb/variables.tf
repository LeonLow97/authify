variable "alb_sg" {
  type = string
}

variable "public_subnets" {
  type = list(string)
}

variable "vpc_id" {
  type = string
}

variable "api_gateway_instance_id_az1" {
  type = string
}
variable "api_gateway_instance_id_az2" {
  type = string
}
