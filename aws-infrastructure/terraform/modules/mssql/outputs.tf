output "name" {
  description = "Instance identifier"
  value       = aws_db_instance.database.identifier
}

output "address" {
  description = "The Database address"
  value       = aws_db_instance.database.address
}

output "endpoint" {
  description = "The Database hostname and port combined"
  value       = aws_db_instance.database.endpoint
}
