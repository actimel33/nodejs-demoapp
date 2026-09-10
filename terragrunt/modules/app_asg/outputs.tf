output "autoscaling_group_name" {
  description = "Имя группы автомасштабирования"
  value       = module.asg.autoscaling_group_name
}

output "autoscaling_group_arn" {
  description = "ARN группы"
  value       = module.asg.autoscaling_group_arn
}

output "autoscaling_policy_arns" {
  description = "ARN политик масштабирования"
  value       = module.asg.autoscaling_policy_arns
}
