output "alb_security_group_id" {
  description = "ID группы балансировщика"
  value       = aws_security_group.alb.id
}

output "app_security_group_id" {
  description = "ID группы приложения"
  value       = aws_security_group.app.id
}

output "docdb_security_group_id" {
  description = "ID группы DocumentDB"
  value       = aws_security_group.docdb.id
}
