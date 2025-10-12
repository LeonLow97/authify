# Application Load Balancer
resource "aws_alb" "ims_alb" {
  name               = "ims-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg]
  subnets            = var.public_subnets

  enable_deletion_protection       = false
  enable_cross_zone_load_balancing = true
  idle_timeout = 60

  tags = {
    Name = "ims-alb"
  }
}

resource "aws_alb_target_group" "api_gateway_tg" {
  name     = "api-gateway-tg"
  protocol = "HTTP"
  port     = 8080
  vpc_id   = var.vpc_id

  health_check {
    path                = "/healthcheck"
    port                = "8080"
    protocol            = "HTTP"
    interval            = 10
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "api-gateway-tg"
  }
}

# Register API Gateway EC2 instances to the Target Group
resource "aws_lb_target_group_attachment" "api_gateway_tg_attachment_az1" {
  target_group_arn = aws_alb_target_group.api_gateway_tg.arn
  target_id        = var.api_gateway_instance_id_az1
  port             = 8080
}
resource "aws_lb_target_group_attachment" "api_gateway_tg_attachment_az2" {
  target_group_arn = aws_alb_target_group.api_gateway_tg.arn
  target_id        = var.api_gateway_instance_id_az2
  port             = 8080
}

# Create the ALB Listener
resource "aws_lb_listener" "ims_alb_listener" {
  load_balancer_arn = aws_alb.ims_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.api_gateway_tg.arn
  }
}
