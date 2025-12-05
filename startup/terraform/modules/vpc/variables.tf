variable "cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "az1" {
  type        = string
  description = "First Availability Zone"
}

variable "az2" {
  type        = string
  description = "Second Availability Zone"
}
