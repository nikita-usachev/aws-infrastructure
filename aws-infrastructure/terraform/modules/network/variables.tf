variable "enabled" {
  default = false
}

variable "private_enabled" {
  default = false
}

variable "endpoints_enabled" {
  default = true
}

variable "nat_enabled" {
  default = true
}

variable "region" {
}

variable "environment" {
}

variable "prefix" {
}

variable "suffix" {
  default = ""
}

variable "vpc_cidr" {
  default = ""
}

variable "public_subnet_cidrs" {
  type    = list(any)
  default = []
}

variable "private_subnet_cidrs" {
  type    = list(any)
  default = []
}

variable "avail_zones" {
  default = 1
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
