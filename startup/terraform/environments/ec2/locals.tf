# Fetch availability zones in the provider region
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  az1 = data.aws_availability_zones.available.names[0]
  az2 = data.aws_availability_zones.available.names[1]
}

data "http" "public_ip" {
  url = "https://checkip.amazonaws.com"
}

locals {
  public_ip = trim(data.http.public_ip.response_body, "\n")
}
