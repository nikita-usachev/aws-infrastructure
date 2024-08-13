variable "instance_count" {
}

variable "instance_type" {
}

variable "instance_disk_size" {
}

variable "instance_ami_pattern" {
}

variable "instance_ami_owner" {
}

variable "avail_zones" {
  type = list(any)
}

variable "subnet_ids" {
  type = list(any)
}

variable "vpc_id" {
}

variable "key_name" {
}

variable "key_path" {
}

variable "username" {
}

variable "environment" {
}

variable "prefix" {
}

variable "suffix" {
}

variable "start_index" {
  type    = number
  default = 1
}

variable "ansible_groups" {
  type = list(any)
}

variable "ansible_variables" {
  type    = map(any)
  default = {}
}

variable "external_ip_list" {
  type    = list(any)
  default = []
}

variable "external_port_list" {
  type    = list(any)
  default = []
}

variable "external_sg_list" {
  type    = list(any)
  default = []
}

variable "elastic_ip_enable" {
  type    = bool
  default = false
}

variable "data_disk_enable" {
  type    = bool
  default = false
}

variable "data_disk_size" {
  default = 10
}

variable "data_disk_type" {
  default = "gp2"
}

variable "spot_price" {
  default = null
}

variable "region" {
  default = null
}

variable "iam_role_policies" {
  type    = list(any)
  default = []
}

variable "iam_role_inline_policy" {
  type    = string
  default = null
}

variable "tags" {
  default = {}
}

variable "user_data" {
  default = null
}

locals {
  common_tags = {
    Environment   = var.environment
    Name          = "${var.prefix}${var.suffix}"
    ProvisionedBy = "terraform"
  }
  tags = merge(var.tags, local.common_tags)
}
