output "vpc_id" {
  value = aws_security_group.db_sg.id
}

output "db_sg_id" {
  value = aws_security_group.db_sg.id
}

output "bastion_sg_id" {
  value = aws_security_group.bastion_sg.id
}

output "auth_sg_id" {
  value = aws_security_group.auth_sg.id
}

output "api_gateway_sg_id" {
  value = aws_security_group.api_gateway_sg.id
}

output "alb_sg_id" {
  value = aws_security_group.alb_sg.id
}
