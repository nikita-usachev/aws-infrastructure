# general

region               = "us-east-1"
prefix               = "infra"
environment          = "prod"
network_enabled      = true
vpc_cidr             = "172.31.0.0/16"
az_count             = 2
az_count_network     = 2
public_subnet_cidrs  = []
private_subnet_cidrs = []
private              = true
private_nat          = true
external_ip_list     = []
external_port_list   = []
key_path_public      = "./id_rsa_prod.pub"
key_path_private     = "./id_rsa_prod"

# dns

dns_enabled       = false
dns_internal_only = true
dns_zone          = "aws.internal"

# backups

backups_enabled = false
backups_schedule = {
  interval      = 24
  interval_unit = "HOURS"
  times         = ["23:45"]
}
backups_retain_count = 7

# instances

ec2_instances = {
  bastion = {
    count     = 1
    type      = "t2.nano"
    disk_size = 20
  }
}

ecr_repositories = []

# database

db_instances = [
  {
    name                  = "postgres"
    type                  = "postgres"
    engine_version        = 13.12
    instance_class        = "db.t3.large"
    storage_type          = "gp3"
    allocated_storage     = 20
    max_allocated_storage = 50
    db_name               = "postgres"
    db_password           = "password"
    db_username           = "postgres"
    parameters            = []
    backup_retention      = 7
    skip_final_snapshot   = false
    ca_cert_identifier    = "rds-ca-2019"
  },
  {
    name                  = "mssql"
    type                  = "mssql"
    engine_version        = "15.00.4316.3.v1"
    instance_class        = "db.t3.medium"
    storage_type          = "gp3"
    allocated_storage     = 20
    max_allocated_storage = 50
    db_password           = "password"
    db_username           = "admin"
    parameters            = []
    backup_retention      = 7
    skip_final_snapshot   = false
    ca_cert_identifier    = "rds-ca-2019"
  }
]

# application

app_dns_name      = "dns_name"
app_desired_count = 2
app_cpu           = 512
app_memory        = 1024
app_environment   = "Production"
# NOTE: image and tag are used only for the initial task creation, change of the values is ignored by terraform to be handled from CI
app_image         = "image"
app_image_tag     = "tag"
