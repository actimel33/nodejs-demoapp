output "alb_dns_name" {
  description = "DNS-имя балансировщика — адрес приложения. Открывать по http://, сертификата у ALB нет"
  value       = module.alb.dns_name
}

output "asg_name" {
  description = "Имя группы автомасштабирования — пригодится для наблюдения в консоли и в CLI"
  value       = module.asg.autoscaling_group_name
}

output "target_group_arn" {
  description = "ARN target group"
  value       = module.alb.target_groups["demoapp"].arn
}

output "vpc_id" {
  description = "ID созданной VPC"
  value       = aws_vpc.main.id
}

output "public_subnet_ids" {
  description = "ID публичных подсетей: ALB и инстансы приложения"
  value       = [for s in aws_subnet.public : s.id]
}

output "private_subnet_ids" {
  description = "ID приватных подсетей: DocumentDB"
  value       = [for s in aws_subnet.private : s.id]
}

output "app_security_group_id" {
  description = "ID security group приложения"
  value       = aws_security_group.app.id
}

output "iam_role_name" {
  description = "Имя IAM-роли инстансов приложения"
  value       = module.asg.iam_role_name
}

output "docdb_endpoint" {
  description = "Адрес кластера DocumentDB. Пустая строка, если enable_docdb = false"
  value       = local.docdb_endpoint
}

output "docdb_secret_arn" {
  description = "ARN секрета с логином и паролем DocumentDB в Secrets Manager"
  value       = local.docdb_secret_arn
}

output "sns_topic_arn" {
  description = "ARN темы SNS с оповещениями о масштабировании"
  value       = var.enable_notifications ? aws_sns_topic.scaling_events[0].arn : ""
}
