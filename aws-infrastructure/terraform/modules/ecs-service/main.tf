# data

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id != null ? false : true
}

# iam

data "aws_iam_policy_document" "service_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "service_role" {
  name               = "${local.common_tags.Name}-service-role"
  assume_role_policy = data.aws_iam_policy_document.service_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-service-role" })
}

resource "aws_iam_role_policy_attachment" "service_policy" {
  role       = aws_iam_role.service_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
}

data "aws_iam_policy_document" "task_assume_policy" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "task_role" {
  name               = "${local.common_tags.Name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-task-role" })
}

resource "aws_iam_policy" "task_policy" {
  count       = var.task_policy != null ? 1 : 0
  name        = "${local.common_tags.Name}-task-policy"
  description = "Additional policy for the task role"
  policy      = var.task_policy
}

resource "aws_iam_role_policy_attachment" "task_policy" {
  count      = var.task_policy != null ? 1 : 0
  role       = aws_iam_role.task_role.name
  policy_arn = aws_iam_policy.task_policy.0.arn
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${local.common_tags.Name}-task-execution-role"
  assume_role_policy = data.aws_iam_policy_document.task_assume_policy.json
  tags               = merge(local.tags, { Name = "${local.common_tags.Name}-task-execution-role" })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "task_execution_policy_inline" {
  count       = var.task_execution_policy != null ? 1 : 0
  name        = "${local.common_tags.Name}-task-execution-policy"
  description = "Additional policy for the task execution role"
  policy      = var.task_execution_policy
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_inline" {
  count      = var.task_execution_policy != null ? 1 : 0
  role       = aws_iam_role.task_execution_role.name
  policy_arn = aws_iam_policy.task_execution_policy_inline.0.arn
}

# security group

resource "aws_security_group" "default" {
  vpc_id      = data.aws_vpc.selected.id
  name        = "${local.common_tags.Name}-service-sg"
  description = "Allow traffic to ${local.common_tags.Name} ECS service"
  tags        = merge(local.tags, { Name = "${local.common_tags.Name}-service-sg" })
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "allowed_cidrs" {
  count             = length(var.allowed_cidrs)
  type              = "ingress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = var.allowed_cidrs
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "allowed_ports" {
  count             = length(var.allowed_ports)
  type              = "ingress"
  from_port         = var.allowed_ports[count.index]
  to_port           = var.allowed_ports[count.index]
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

resource "aws_security_group_rule" "external_security_groups" {
  count                    = length(var.allowed_security_groups)
  type                     = "ingress"
  from_port                = 0
  to_port                  = 65535
  protocol                 = "-1"
  source_security_group_id = var.allowed_security_groups[count.index]
  security_group_id        = aws_security_group.default.id
}

resource "aws_security_group_rule" "outgoing" {
  type              = "egress"
  from_port         = 0
  to_port           = 65535
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
  security_group_id = aws_security_group.default.id
}

# task

resource "aws_cloudwatch_log_group" "default" {
  name              = local.common_tags.Name
  retention_in_days = 3
  tags              = local.tags
}

resource "aws_ecs_task_definition" "default" {
  family                   = local.common_tags.Name
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.container_cpu
  memory                   = var.container_mem
  execution_role_arn       = aws_iam_role.task_execution_role.arn
  task_role_arn            = aws_iam_role.task_role.arn
  container_definitions = jsonencode([{
    name        = "${local.common_tags.Name}-container"
    image       = "${var.container_image}:${var.container_tag}"
    essential   = true
    environment = var.container_environment
    secrets     = var.container_secrets
    linuxParameters = {
      initProcessEnabled = true
    }
    portMappings = [{
      protocol      = "tcp"
      containerPort = var.container_port
      hostPort      = var.container_port
    }]
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-region"        = var.region
        "awslogs-group"         = aws_cloudwatch_log_group.default.name
        "awslogs-stream-prefix" = local.common_tags.Name
      }
    }
  }])
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-task" })
}

# service

resource "aws_ecs_service" "default" {
  name                               = "${local.common_tags.Name}-service"
  cluster                            = var.ecs_cluster_id
  task_definition                    = aws_ecs_task_definition.default.arn
  desired_count                      = var.desired_count
  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200
  launch_type                        = "FARGATE"
  scheduling_strategy                = "REPLICA"
  network_configuration {
    security_groups  = [aws_security_group.default.id]
    subnets          = var.subnet_ids
    assign_public_ip = false
  }
  dynamic "load_balancer" {
    for_each = var.alb_listener_arn != null ? [1] : []
    content {
      target_group_arn = aws_lb_target_group.default.0.arn
      container_name   = "${local.common_tags.Name}-container"
      container_port   = var.container_port
    }
  }
  enable_execute_command = var.enable_execute_command
  tags                   = merge(local.tags, { Name = "${local.common_tags.Name}-service" })
  lifecycle {
    # ignore_changes = [task_definition, desired_count]
    ignore_changes = [task_definition]
  }
}

# alb

resource "aws_lb_target_group" "default" {
  count       = 1 # var.alb_listener_arn != null ? 1 : 0
  name        = "${local.common_tags.Name}-service-target"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = data.aws_vpc.selected.id
  target_type = "ip"
  health_check {
    path                = var.alb_healthcheck_path
    protocol            = "HTTP"
    timeout             = var.alb_healthcheck_timeout
    interval            = var.alb_healthcheck_interval
    healthy_threshold   = 5
    unhealthy_threshold = 2
    matcher             = "200"
  }
  tags = merge(local.tags, { Name = "${local.common_tags.Name}-service-target" })
}

resource "aws_alb_listener_rule" "alb" {
  count        = 1 # var.alb_listener_arn != null ? 1 : 0
  listener_arn = var.alb_listener_arn
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.default.0.arn
  }
  condition {
    host_header {
      values = ["*${var.service_fqdn}"]
    }
  }
}
