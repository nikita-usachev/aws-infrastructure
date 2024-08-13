locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}

variable "environment" {
}

variable "lifecycle_rules" {
  type = list(object({
    name = string
    expiration = object({
      days = number
    })
  }))
  default = []
}

variable "prefix" {
}

variable "suffix" {
}

variable "object_ownership" {
  default = "BucketOwnerPreferred"
}

variable "tags" {
  default = {}
}
