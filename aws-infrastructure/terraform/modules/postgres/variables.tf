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

variable "avail_zone" {
  default = null
  type    = string
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "instance_class" {
  type    = string
  default = "db.t3.small"
}

variable "storage_encrypted" {
  type    = bool
  default = false
}

variable "engine_version" {
  type    = string
  default = "14.6"
}

variable "database_engine" {
  type    = string
  default = "postgres"
}

variable "database_security_group_description" {
  type    = string
  default = "RDS PostgreSQL"
}

variable "storage_type" {
  type    = string
  default = "gp3"
}

variable "allocated_storage" {
  type    = number
  default = 5
}

variable "max_allocated_storage" {
  type    = number
  default = null
}

variable "multi_az" {
  type    = bool
  default = false
}

variable "database_name" {
  type = string
}

variable "database_username" {
  type = string
}

variable "database_password" {
  type = string
}

variable "database_port" {
  default = 5432
  type    = number
}

variable "security_groups" {
  type    = list(any)
  default = []
}

variable "backup_retention" {
  type    = number
  default = 7
}

variable "snapshot_identifier" {
  type    = string
  default = null
}

variable "skip_final_snapshot" {
  type    = bool
  default = null
}

variable "apply_immediately" {
  type    = bool
  default = null
}

variable "deletion_protection" {
  type    = bool
  default = null
}

variable "parameters_additional" {
  type    = list(map(string))
  default = []
}

variable "parameters_default" {
  type = list(map(string))
  default = [
    {
      name  = "log_duration"
      value = 1
    }
  ]
}

variable "ca_cert_identifier" {
  type    = string
  default = "rds-ca-2019"
}

variable "cloudwatch_logs_exports" {
  default = []
  type    = list(any)
}

variable "iam_database_authentication_enabled" {
  default = false
  type    = bool
}

variable "tags" {
  default = {}
  type    = map(any)
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    ProvisionedBy = "terraform"
  }
  tags       = merge(var.tags, local.common_tags)
  parameters = concat(var.parameters_default, var.parameters_additional)
}
