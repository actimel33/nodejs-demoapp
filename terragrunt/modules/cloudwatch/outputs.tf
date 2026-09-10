output "sns_topic_arn" {
  description = "ARN темы с оповещениями о масштабировании"
  value       = aws_sns_topic.this.arn
}

output "subscription_arn" {
  description = "ARN подписки. Значение 'pending confirmation' означает, что ссылку из письма ещё не нажали"
  value       = var.alert_email != "" ? aws_sns_topic_subscription.email[0].arn : ""
}

output "alarm_names" {
  description = "Имена созданных алармов"
  value       = compact([aws_cloudwatch_metric_alarm.high_cpu.alarm_name, try(aws_cloudwatch_metric_alarm.high_latency[0].alarm_name, "")])
}
