# Public zone

resource "aws_route53_zone" "public" {
  count         = var.enabled && var.public ? 1 : 0
  name          = var.dns_zone
  force_destroy = true
  tags          = merge(local.tags, { type = "public" })
}

resource "aws_route53_record" "public" {
  count   = var.enabled && var.public ? length(var.dns_records_public) : 0
  zone_id = aws_route53_zone.public.0.zone_id
  name    = "${var.dns_records_public[count.index].name}.${var.dns_zone}"
  type    = "CNAME"
  ttl     = 300
  records = [var.dns_records_public[count.index].cname]
}

# Private zone

resource "aws_route53_zone" "private" {
  count         = var.enabled && var.private ? 1 : 0
  name          = var.dns_zone
  force_destroy = true
  vpc {
    vpc_id = var.vpc_id
  }
  tags = merge(local.tags, { type = "private" })
}

resource "aws_route53_record" "private" {
  count   = var.enabled && var.private ? length(var.dns_records_private) : 0
  zone_id = aws_route53_zone.private.0.zone_id
  name    = "${var.dns_records_private[count.index].name}.${var.dns_zone}"
  type    = "CNAME"
  ttl     = 300
  records = [var.dns_records_private[count.index].cname]
}
