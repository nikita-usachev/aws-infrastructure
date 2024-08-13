variable "region" {
  default = "us-east-1"
}

variable "prefix" {
  default = "app"
}

variable "environment" {
  default = null
}

variable "key_path_public" {
  default = "~/.ssh/id_rsa.pub"
}

variable "key_path_private" {
  default = "~/.ssh/id_rsa"
}

variable "network_enabled" {
  default = false
}

variable "alb_internal" {
  type    = bool
  default = false
}

variable "vpc_cidr" {
  default = null
}

variable "private_subnet_cidrs" {
  default = null
}

variable "public_subnet_cidrs" {
  default = null
}

variable "vpn_enabled" {
  default = true
}

variable "vpn_client_cidr" {
  default = ""
}

variable "vpn_clients" {
  default = []
}

variable "instance_ami_owner" {
  default = ""
}

variable "instance_ami_pattern" {
  default = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "username" {
  default = "ubuntu"
}

variable "external_ip_list" {
  type    = list(any)
  default = ["0.0.0.0/0"]
}

variable "external_port_list" {
  type    = list(any)
  default = [80, 443]
}

variable "az_count" {
  default = 1
}

variable "az_count_network" {
  default = 1
}

variable "private" {
  default = false
}

variable "private_nat" {
  default = true
}

variable "vpc_id" {
  default = null
}

variable "dns_enabled" {
  type    = bool
  default = false
}

variable "dns_zone" {
  type    = string
  default = ""
}

variable "dns_force_destroy" {
  default = true
}

variable "dns_internal_only" {
  type    = bool
  default = true
}

variable "dns_create_records_ext" {
  type    = bool
  default = true
}

variable "dns_create_records_int" {
  type    = bool
  default = true
}

variable "backups_enabled" {
  type    = bool
  default = false
}

variable "backups_schedule" {
  default = {
    interval      = 24
    interval_unit = "HOURS"
    times         = ["23:45"]
  }
}

variable "backups_retain_count" {
  type    = number
  default = 7
}

variable "app_desired_count" {
  type    = number
  default = 1
}

variable "app_dns_name" {
  type    = string
  default = ""
}

variable "app_cpu" {
  type    = number
  default = 256
}

variable "app_memory" {
  type    = number
  default = 512
}

variable "app_environment" {
  type    = string
  default = ""
}

variable "app_image" {
  type    = string
  default = ""
}

variable "app_image_tag" {
  type    = string
  default = "latest"
}

variable "ecr_repositories" {
  type = list(object({
    name = string
  }))
  default = []
}

# Example of instance group definition
# ec2_instances = {
#   bastion = {
#     count       = 1
#     type        = "t3.micro"
#     disk_size   = 20
#     ami_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
#     spot_price  = 0.01
#   }
#   app = {
#     count       = 2
#     type        = "t3.micro"
#     disk_size   = 30
#     ami_pattern = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
#   }
# }
variable "ec2_instances" {
  type    = map(any)
  default = {}
}

variable "ipsec_connections" {
  type = list(object({
    name             = string
    ip_address       = optional(string)
    local_cidr       = optional(string)
    remote_cidr      = optional(string)
    static_routes    = optional(list(string))
    use_attached_vpg = optional(bool)
  }))
  default = []
}

variable "gitlab_cache_bucket_enabled" {
  default = false
}

locals {
  environment = var.environment != null ? var.environment : "${terraform.workspace}"
  suffix      = terraform.workspace == "default" ? "" : "-${terraform.workspace}"
}

variable "db_instances" {
  type = list(object({
    name                    = string
    type                    = string
    instance_class          = optional(string)
    engine_version          = optional(string)
    storage_type            = optional(string)
    allocated_storage       = optional(number)
    max_allocated_storage   = optional(number)
    dns_prefix              = optional(string)
    db_name                 = optional(string)
    db_username             = optional(string)
    db_password             = optional(string)
    multi_az                = optional(bool)
    parameters              = optional(list(map(string)))
    cloudwatch_logs_exports = optional(list(string))
    # security_groups         = optional(list(string))
    backup_retention                    = optional(number)
    deletion_protection                 = optional(bool)
    skip_final_snapshot                 = optional(bool)
    snapshot_identifier                 = optional(string)
    ca_cert_identifier                  = optional(string)
    iam_database_authentication_enabled = optional(bool)
  }))
  default = []
}
