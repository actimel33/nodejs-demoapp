output "cluster_identifier" {
  description = "Идентификатор кластера"
  value       = aws_docdb_cluster.this.cluster_identifier
}

output "endpoint" {
  description = "Адрес кластера — всегда указывает на текущий primary, сюда пишем"
  value       = aws_docdb_cluster.this.endpoint
}

output "reader_endpoint" {
  description = "Адрес для чтения — балансирует по репликам"
  value       = aws_docdb_cluster.this.reader_endpoint
}

output "port" {
  description = "Порт кластера"
  value       = aws_docdb_cluster.this.port
}

output "master_secret_arn" {
  description = "ARN секрета с логином и паролем в Secrets Manager"
  value       = aws_docdb_cluster.this.master_user_secret[0].secret_arn
}

output "read_secret_policy_arn" {
  description = "ARN IAM-политики на чтение секрета — прицепляется к роли инстансов приложения"
  value       = var.create_secret_read_policy ? aws_iam_policy.read_secret[0].arn : ""
}
