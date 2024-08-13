variable "environment" {
  type = string
}

variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "subnet_ids" {
  type = list(string)
}

variable "internal" {
  type    = bool
  default = true
}

variable "ssl_enabled" {
  type    = bool
  default = false
}

variable "full_domain" {
  type = string
}

variable "target_instances" {
  type    = list(any)
  default = []
}

variable "idle_timeout" {
  default = 60
}

variable "deregistration_delay" {
  default = null
}

variable "tags" {
  default = {}
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
