variable "enabled" {
  type    = bool
  default = false
}

variable "private" {
  type    = bool
  default = true
}

variable "public" {
  type    = bool
  default = false
}

variable "vpc_id" {
}

variable "environment" {
}

variable "force_destroy" {
  default = true
}

variable "tags" {
  default = {}
}

variable "dns_zone" {
  type    = string
  default = ""
}

variable "dns_records_public" {
  type = list(object({
    name  = string
    cname = string
  }))
  default = []
}

variable "dns_records_private" {
  type = list(object({
    name  = string
    cname = string
  }))
  default = []
}

locals {
  common_tags = {
    environment   = var.environment
    provisionedby = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
