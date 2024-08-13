# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# security group

resource "aws_security_group" "alb" {
  name        = "${local.common_tags.Name}-sg"
  description = "Allow ALB traffic"
  vpc_id      = data.aws_vpc.selected.id
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-sg" })
}

resource "aws_security_group_rule" "alb_allow_http" {
  description       = "Inbound HTTP traffic"
  type              = "ingress"
  from_port         = "80"
  to_port           = "80"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_allow_https" {
  count             = var.ssl_enabled ? 1 : 0
  description       = "Inbound HTTPS traffic"
  type              = "ingress"
  from_port         = "443"
  to_port           = "443"
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

resource "aws_security_group_rule" "alb_outbound" {
  description       = "Outbound traffic anywhere"
  type              = "egress"
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.alb.id
}

# certificate

resource "aws_acm_certificate" "default" {
  count       = var.ssl_enabled ? 1 : 0
  domain_name = var.full_domain
  subject_alternative_names = [
    "www.${var.full_domain}"
  ]
  validation_method = "DNS"
  tags              = merge(local.tags, { Name = "${local.common_tags.Name}-cert" })
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "default" {
  count           = var.ssl_enabled ? 1 : 0
  certificate_arn = aws_acm_certificate.default.0.arn
}

# balancer

resource "aws_lb" "alb" {
  name                       = local.common_tags.Name
  internal                   = var.internal
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb.id]
  subnets                    = var.subnet_ids
  idle_timeout               = var.idle_timeout
  enable_deletion_protection = false
  tags                       = merge(local.tags, { Name = local.common_tags.Name })
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"
  dynamic "default_action" {
    for_each = var.ssl_enabled ? [1] : []
    content {
      type = "redirect"
      redirect {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }
  }
  dynamic "default_action" {
    for_each = !var.ssl_enabled ? [1] : []
    content {
      type = "fixed-response"
      fixed_response {
        content_type = "text/plain"
        message_body = "ok"
        status_code  = "200"
      }
    }
  }
  depends_on = [aws_lb.alb]
}

resource "aws_lb_listener" "https" {
  count             = var.ssl_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate_validation.default.0.certificate_arn
  default_action {
    type = "fixed-response"
    fixed_response {
      content_type = "text/plain"
      message_body = "ok"
      status_code  = "200"
    }
  }
}

# targets

resource "aws_lb_target_group" "alb" {
  count                = length(var.target_instances) > 0 ? 1 : 0
  name                 = "${local.common_tags.Name}-target"
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = data.aws_vpc.selected.id
  target_type          = "instance"
  deregistration_delay = var.deregistration_delay
  health_check {
    path                = "/"
    protocol            = "HTTP"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
  stickiness {
    enabled = false
    type    = "lb_cookie"
  }
  tags       = merge(local.tags, { Name = "${local.common_tags.Name}-target" })
  depends_on = [aws_acm_certificate_validation.default]
}

resource "aws_alb_listener_rule" "alb" {
  count        = length(var.target_instances) > 0 ? 1 : 0
  listener_arn = var.ssl_enabled ? aws_lb_listener.https.0.arn : aws_lb_listener.http.arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb.0.arn
  }
  condition {
    host_header {
      values = ["*${var.full_domain}"]
    }
  }
}

resource "aws_lb_target_group_attachment" "alb" {
  count            = length(var.target_instances)
  target_group_arn = aws_lb_target_group.alb.0.arn
  target_id        = var.target_instances[count.index]
  port             = 80
}
