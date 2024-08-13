output "name_servers" {
  value = var.enabled && var.public ? aws_route53_zone.public[0].name_servers : null
}

output "dns_zone_id_private" {
  value = var.enabled && var.private ? aws_route53_zone.private[0].zone_id : null
}

output "dns_zone_id_public" {
  value = var.enabled && var.public ? aws_route53_zone.public[0].zone_id : null
}
