variable "environment" {
  type = string
}

variable "name" {
  type = string
}

variable "attributes" {
  type        = list(string)
  description = "Additional attributes (e.g. `policy` or `role`)"
  default     = []
}

variable "principals_full_access" {
  type        = list(string)
  description = "Principal ARNs to provide with full access to the ECR"
  default     = []
}

variable "principals_readonly_access" {
  type        = list(string)
  description = "Principal ARNs to provide with readonly access to the ECR"
  default     = []
}

variable "max_image_count" {
  type        = number
  description = "How many docker image versions AWS ECR will store"
  default     = 500
}

variable "tags" {
  type    = map(string)
  default = {}
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = var.name
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
