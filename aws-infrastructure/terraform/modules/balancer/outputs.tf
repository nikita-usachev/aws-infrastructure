output "arn" {
  description = "The ARN of the Load Balancer"
  value       = aws_lb.alb.arn
}

output "listener_arn" {
  description = "The ARN of the Listener"
  value       = var.ssl_enabled ? aws_lb_listener.https.0.arn : aws_lb_listener.http.arn
}

output "dns_name" {
  description = "The DNS name of the Load Balancer"
  value       = aws_lb.alb.dns_name
}

output "zone_id" {
  description = "The canonical hosted zone ID of the load balancer (to be used in a Route 53 Alias record)."
  value       = aws_lb.alb.zone_id
}

output "security_group_id" {
  description = "The Balancer's Security Group"
  value       = aws_security_group.alb.id
}
