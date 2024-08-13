output "bastion" {
  value = var.ec2_instances.bastion.count > 0 ? "ssh -i ${var.key_path_private} ${var.username}@${module.bastion[0].ansible[0].vars.ansible_host}" : null
}

output "postgres" {
  value = module.postgres["postgres"].endpoint
}

output "mssql" {
  value = module.mssql["mssql"].endpoint
}

output "app-endpoint" {
  value = "https://${var.app_dns_name}"
}

output "name_servers" {
  value       = var.dns_enabled && !var.dns_internal_only ? module.dns.name_servers : null
  description = "DNS zone name servers"
}
