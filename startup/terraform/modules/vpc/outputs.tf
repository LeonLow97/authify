output "vpc_id" {
  value = aws_vpc.main.id
}

output "public_subnets" {
  value = [aws_subnet.public_az1.id, aws_subnet.public_az2.id]
}

output "private_subnets" {
  value = [aws_subnet.private_az1.id, aws_subnet.private_az2.id]
}

output "private_rds_subnets" {
  value = [aws_subnet.private_rds_az1.id, aws_subnet.private_rds_az2.id]
}

output "internet_gateway_id" {
  value = aws_internet_gateway.main.id
}

output "public_route_table_id" {
  value = aws_route_table.public.id
}
