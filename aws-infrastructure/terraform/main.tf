# provider

provider "aws" {
  region = var.region
}

# data

data "aws_availability_zones" "selected" {}

# key

resource "aws_key_pair" "key" {
  key_name   = "${var.prefix}${local.suffix}"
  public_key = file(var.key_path_public)
  lifecycle {
    ignore_changes = [public_key]
  }
}

# network

module "network" {
  source               = "./modules/network"
  enabled              = var.network_enabled
  region               = var.region
  prefix               = var.prefix
  suffix               = local.suffix
  environment          = local.environment
  vpc_cidr             = var.vpc_cidr
  private_enabled      = var.private
  nat_enabled          = var.private_nat
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count_network)
  tags = {
    Application = "infra"
    Component   = "vpc"
  }
}

module "dns" {
  source             = "./modules/dns"
  enabled            = var.dns_enabled
  environment        = local.environment
  dns_zone           = var.dns_zone
  private            = true
  public             = var.dns_internal_only ? false : true
  vpc_id             = var.network_enabled ? module.network.vpc_id : var.vpc_id
  force_destroy      = var.dns_force_destroy
  dns_records_public = []
  dns_records_private = var.dns_create_records_int ? concat(
    [{ name = "app", cname = module.balancer.dns_name }],
    []
  ) : []
  tags = {
    Application = "infra"
    Component   = "dns"
  }
  depends_on = [module.network]
}

module "vpn" {
  source            = "./modules/vpn"
  count             = var.vpn_enabled ? 1 : 0
  region            = var.region
  environment       = local.environment
  prefix            = var.prefix
  suffix            = "-vpn${local.suffix}"
  vpc_id            = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids        = var.network_enabled ? slice(module.network.public_subnet_ids, 0, var.az_count) : null
  client_cidr_block = var.vpn_client_cidr
  clients           = var.vpn_clients
  tags = {
    Application = "infra"
    Component   = "vpn"
  }
  depends_on = [module.network]
}

# bastion

module "bastion" {
  count                = try(var.ec2_instances.bastion, null) != null ? 1 : 0
  source               = "./modules/instances"
  instance_count       = lookup(var.ec2_instances.bastion, "count", 0)
  instance_type        = lookup(var.ec2_instances.bastion, "type", null)
  instance_disk_size   = lookup(var.ec2_instances.bastion, "disk_size", null)
  instance_ami_pattern = var.instance_ami_pattern
  instance_ami_owner   = var.instance_ami_owner
  key_name             = aws_key_pair.key.key_name
  key_path             = var.key_path_private
  username             = var.username
  environment          = local.environment
  prefix               = var.prefix
  suffix               = "-bastion${local.suffix}"
  ansible_groups       = ["all", "bastion"]
  avail_zones          = slice(data.aws_availability_zones.selected.names, 0, var.az_count)
  external_ip_list     = var.external_ip_list
  external_port_list   = [22]
  external_sg_list     = []
  vpc_id               = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids           = var.network_enabled ? module.network.public_subnet_ids : null
  elastic_ip_enable    = false
  tags = {
    Application = "infra"
    Component   = "bastion"
  }
  # spot
  spot_price = lookup(var.ec2_instances.bastion, "spot_price", null)
  region     = var.region
  depends_on = [module.network]
}

# dlm-backup

module "backups" {
  source       = "./modules/dlm"
  count        = var.backups_enabled ? 1 : 0
  environment  = terraform.workspace
  prefix       = var.prefix
  suffix       = "-backups${local.suffix}"
  schedule     = var.backups_schedule
  retain_count = var.backups_retain_count
  tags = {
    Application = "infra"
    Component   = "backups"
  }
}

module "iam" {
  source      = "./modules/iam"
  environment = terraform.workspace
  prefix      = var.prefix
  suffix      = "-iam${local.suffix}"
  tags = {
    Application = "infra"
    Component   = "IAM"
  }
}

module "ecr-repositories" {
  source                     = "./modules/ecr"
  for_each                   = { for repo in var.ecr_repositories : repo.name => repo }
  environment                = terraform.workspace
  name                       = each.key
  principals_full_access     = []
  principals_readonly_access = []
  tags = {
    Application = "name"
    Component   = "ECR"
  }
}

module "ecs-cluster" {
  source      = "./modules/ecs-cluster"
  environment = local.environment
  prefix      = var.prefix
  suffix      = "-ecs${local.suffix}"
  tags = {
    Application = "name"
    Component   = "ECS"
  }
  depends_on = [module.network]
}

module "ecs-bw-api-service" {
  source      = "./modules/ecs-service"
  region      = var.region
  environment = local.environment
  prefix      = var.prefix
  suffix      = local.suffix
  name        = "api"
  vpc_id      = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids  = var.network_enabled ? module.network.private_subnet_ids : null
  allowed_security_groups = concat(
    var.ec2_instances.bastion.count > 0 ? [module.bastion[0].sg_id] : [],
    var.vpn_enabled ? [module.vpn[0].client_vpn_security_group_id] : [],
    [module.balancer.security_group_id]
  )
  ecs_cluster_id           = module.ecs-cluster.id
  alb_listener_arn         = module.balancer.listener_arn
  alb_healthcheck_path     = "/health"
  alb_healthcheck_interval = 60
  alb_healthcheck_timeout  = 30
  service_fqdn             = var.app_dns_name
  container_image          = var.app_image
  container_tag            = var.app_image_tag
  container_port           = 80
  container_cpu            = var.app_cpu
  container_mem            = var.app_memory
  desired_count            = var.app_desired_count
  container_environment = [
    { name = "ENVIRONMENT", value = var.app_environment }
  ]
  container_secrets = []
  task_execution_policy  = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": "arn:aws:ssm:us-east-1:ACCOUNT_ID:parameter/${local.environment}_*"
        }
    ]
}
EOF
  enable_execute_command = true
  tags = {
    Application = "name"
    Component   = "api"
  }
  depends_on = [module.ecs-cluster]
}

module "balancer" {
  source      = "./modules/balancer"
  environment = local.environment
  prefix      = var.prefix
  suffix      = "-balancer${local.suffix}"
  vpc_id      = var.network_enabled ? module.network.vpc_id : var.vpc_id
  subnet_ids  = !var.network_enabled ? null : var.alb_internal ? module.network.private_subnet_ids : module.network.public_subnet_ids
  internal    = var.alb_internal
  ssl_enabled = true
  full_domain = var.app_dns_name
  tags = {
    Application = "name"
    Component   = "balancer"
  }
}

# ansible inventory

resource "ansible_group" "all" {
  inventory_group_name = "all"
  vars = {
    cloud_inventory_cloud             = "aws"
    cloud_inventory_region            = var.region
    cloud_inventory_env               = terraform.workspace
    cloud_inventory_ip_whitelist      = join(",", var.external_ip_list)
    cloud_inventory_dns_zone          = !var.dns_enabled ? null : "${terraform.workspace}.${var.dns_zone}"
    cloud_inventory_dns_internal_only = var.dns_internal_only
  }
}

# databases

module "postgres" {
  source                  = "./modules/postgres"
  for_each                = { for index, key in var.db_instances : key.name => key if key.type == "postgres" }
  environment             = terraform.workspace
  prefix                  = var.prefix
  suffix                  = "-${each.key}-db-${terraform.workspace}"
  instance_class          = lookup(each.value, "instance_class", null)
  multi_az                = lookup(each.value, "multi_az", null)
  storage_type            = lookup(each.value, "storage_type", null)
  allocated_storage       = lookup(each.value, "allocated_storage", null)
  max_allocated_storage   = lookup(each.value, "max_allocated_storage", null)
  database_name           = lookup(each.value, "db_name", null)
  database_username       = lookup(each.value, "db_username", null)
  database_password       = lookup(each.value, "db_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  security_groups = concat(
    [var.ec2_instances.bastion.count > 0 ? module.bastion[0].sg_id : null],
    [module.ecs-bw-api-service.sg_id],
    lookup(each.value, "security_groups", [])
  )
  backup_retention                    = lookup(each.value, "backup_retention", null)
  deletion_protection                 = lookup(each.value, "deletion_protection", null)
  snapshot_identifier                 = lookup(each.value, "db_snapshot", null)
  iam_database_authentication_enabled = lookup(each.value, "iam_database_authentication_enabled", false)
  vpc_id                              = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids                  = var.network_enabled ? module.network.private_subnet_ids : null
  avail_zone                          = data.aws_availability_zones.selected.names[0]
  tags = {
    Application = "name"
    Component   = "postgres"
  }
  depends_on = [module.network]
}

module "mssql" {
  source                  = "./modules/mssql"
  for_each                = { for index, key in var.db_instances : key.name => key if key.type == "mssql" }
  environment             = terraform.workspace
  prefix                  = var.prefix
  suffix                  = "-${each.key}-db-${terraform.workspace}"
  instance_class          = lookup(each.value, "instance_class", null)
  multi_az                = lookup(each.value, "multi_az", null)
  storage_type            = lookup(each.value, "storage_type", null)
  allocated_storage       = lookup(each.value, "allocated_storage", null)
  max_allocated_storage   = lookup(each.value, "max_allocated_storage", null)
  database_name           = lookup(each.value, "db_name", null)
  database_username       = lookup(each.value, "db_username", null)
  database_password       = lookup(each.value, "db_password", null)
  engine_version          = lookup(each.value, "engine_version", null)
  parameters_additional   = lookup(each.value, "parameters", [])
  cloudwatch_logs_exports = lookup(each.value, "cloudwatch_logs_exports", null)
  security_groups = concat(
    [var.ec2_instances.bastion.count > 0 ? module.bastion[0].sg_id : null],
    [module.ecs-bw-api-service.sg_id],
    lookup(each.value, "security_groups", [])
  )
  backup_retention                    = lookup(each.value, "backup_retention", null)
  deletion_protection                 = lookup(each.value, "deletion_protection", null)
  snapshot_identifier                 = lookup(each.value, "db_snapshot", null)
  iam_database_authentication_enabled = lookup(each.value, "iam_database_authentication_enabled", false)
  vpc_id                              = var.network_enabled ? module.network.vpc_id : var.vpc_id
  private_subnet_ids                  = var.network_enabled ? module.network.private_subnet_ids : null
  avail_zone                          = data.aws_availability_zones.selected.names[0]
  tags = {
    Application = "name"
    Component   = "mssql"
  }
  depends_on = [module.network]
}

# provisioners

#resource "null_resource" "provision" {
#  triggers = {
#    random_uuid = uuid()
#  }
#  provisioner "local-exec" {
#    command = "wget -O ./terraform.py https://raw.githubusercontent.com/nbering/terraform-inventory/master/terraform.py && chmod +x ./terraform.py"
#  }
#}
