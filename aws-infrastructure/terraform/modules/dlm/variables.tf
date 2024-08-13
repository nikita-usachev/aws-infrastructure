variable "environment" {
  type = string
}

variable "prefix" {
  type = string
}

variable "suffix" {
  type = string
}

variable "schedule" {
  default = {
    interval      = 24
    interval_unit = "HOURS"
    times         = ["23:45"]
  }
}

variable "retain_count" {
  default = 14
}

variable "target_tags" {
  default = {
    Snapshot = "true"
  }
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
