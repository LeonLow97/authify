# VPC
resource "aws_vpc" "main" {
  cidr_block           = var.cidr_block
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "main-vpc"
  }
}

# Public Subnets
resource "aws_subnet" "public_az1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = var.az1
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-az1" }
}

resource "aws_subnet" "public_az2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = var.az2
  map_public_ip_on_launch = true
  tags                    = { Name = "public-subnet-az2" }
}

# Private Subnets
resource "aws_subnet" "private_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = var.az1
  tags              = { Name = "private-subnet-az1" }
}

resource "aws_subnet" "private_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = var.az2
  tags              = { Name = "private-subnet-az2" }
}

# Private RDS Subnets
resource "aws_subnet" "private_rds_az1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.5.0/24"
  availability_zone = var.az1
  tags              = { Name = "private-rds-subnet-az1" }
}

resource "aws_subnet" "private_rds_az2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.6.0/24"
  availability_zone = var.az2
  tags              = { Name = "private-rds-subnet-az2" }
}

# Create Internet Gateway and attach it to VPC
resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main-igw"
  }
}

# Create a Public Route Table and associate with IGW in VPC
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0" # internet
    gateway_id = aws_internet_gateway.main.id
  }

  tags = {
    Name = "public-route-table"
  }
}

# Associate Route Table with Public Subnet AZ1
resource "aws_route_table_association" "public_az1" {
  subnet_id      = aws_subnet.public_az1.id
  route_table_id = aws_route_table.public.id
}

# Associate Route Table with Public Subnet AZ2
resource "aws_route_table_association" "public_az2" {
  subnet_id      = aws_subnet.public_az2.id
  route_table_id = aws_route_table.public.id
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_eip_az1" {
  tags = {
    Name = "nat-eip-az1"
  }
}
resource "aws_eip" "nat_eip_az2" {
  tags = {
    Name = "nat-eip-az2"
  }
}

# NAT Gateway
resource "aws_nat_gateway" "nat_gw_az1" {
  allocation_id = aws_eip.nat_eip_az1.id
  subnet_id     = aws_subnet.public_az1.id
  tags = {
    Name = "nat-gw-az1"
  }

  depends_on = [aws_internet_gateway.main] # ensures IGW is attached before NAT GW is created
}
resource "aws_nat_gateway" "nat_gw_az2" {
  allocation_id = aws_eip.nat_eip_az2.id
  subnet_id     = aws_subnet.public_az2.id
  tags = {
    Name = "nat-gw-az2"
  }

  depends_on = [aws_internet_gateway.main] # ensures IGW is attached before NAT GW is created
}

# Route Table for Private Subnet AZ1 and AZ2
resource "aws_route_table" "private_az1" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rtb-az1"
  }
}
resource "aws_route_table" "private_az2" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "private-rtb-az2"
  }
}

# Associate Private Route Table to the internet
resource "aws_route" "nat_route_az1" {
  route_table_id         = aws_route_table.private_az1.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw_az1.id

  depends_on = [ aws_nat_gateway.nat_gw_az1 ]
}
resource "aws_route" "nat_route_az2" {
  route_table_id         = aws_route_table.private_az2.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat_gw_az2.id

  depends_on = [ aws_nat_gateway.nat_gw_az2 ]
}

# Associate Route Table to Private Subnets in AZ1 and AZ2
resource "aws_route_table_association" "private_az1_assoc" {
  subnet_id      = aws_subnet.private_az1.id
  route_table_id = aws_route_table.private_az1.id
}
resource "aws_route_table_association" "private_az2_assoc" {
  subnet_id      = aws_subnet.private_az2.id
  route_table_id = aws_route_table.private_az2.id
}
