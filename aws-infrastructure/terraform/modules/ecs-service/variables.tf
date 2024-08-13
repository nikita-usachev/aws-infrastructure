variable "environment" {
  type        = string
  default     = null
  description = "Environment name aka terraform workspace."
}

variable "prefix" {
  type        = string
  default     = "jcash-"
  description = "Environment prefix, is used in resources name generation."
}

variable "suffix" {
  type        = string
  default     = "-dev"
  description = "Environment suffix, is used in resources name generation."
}

variable "region" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "name" {
  type = string
}

variable "ecs_cluster_id" {
  type = string
}

variable "alb_listener_arn" {
  type    = string
  default = null
}

variable "alb_healthcheck_interval" {
  type    = number
  default = 60
}

variable "alb_healthcheck_timeout" {
  type    = number
  default = 30
}

variable "alb_healthcheck_path" {
  type    = string
  default = "/"
}

variable "subnet_ids" {
  type = list(string)
}

variable "allowed_security_groups" {
  type    = list(string)
  default = []
}

variable "allowed_ports" {
  type    = list(string)
  default = []
}

variable "allowed_cidrs" {
  type    = list(string)
  default = []
}

# This policy enables ECS execute command permissions, requires `enable_execute_command = true` variable
# TODO: enable audit and logging for exec feature for production use
# https://aws.amazon.com/blogs/containers/new-using-amazon-ecs-exec-access-your-containers-fargate-ec2
variable "task_policy" {
  type    = string
  default = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssmmessages:CreateControlChannel",
                "ssmmessages:CreateDataChannel",
                "ssmmessages:OpenControlChannel",
                "ssmmessages:OpenDataChannel",
                "ssm:StartSession"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

variable "task_execution_policy" {
  type    = string
  default = null
}

variable "desired_count" {
  type    = number
  default = 1
}

variable "container_cpu" {
  type    = number
  default = 256
}

variable "container_mem" {
  type    = number
  default = 512
}

variable "container_port" {
  type    = number
  default = 80
}

variable "container_image" {
  type    = string
  default = "nginx"
}

variable "container_tag" {
  type    = string
  default = "latest"
}

variable "service_fqdn" {
  type    = string
  default = ""
}

variable "container_environment" {
  type    = list(any)
  default = []
}

variable "container_secrets" {
  type    = list(any)
  default = []
}

variable "enable_execute_command" {
  type    = bool
  default = false
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "A map of tags to apply for the resources."
}

locals {
  common_tags = {
    environment   = var.environment
    Name          = "${var.prefix}${var.suffix}-${var.name}"
    provisionedby = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
