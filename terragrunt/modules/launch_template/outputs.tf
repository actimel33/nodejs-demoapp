output "launch_template_id" {
  description = "ID шаблона — его потребляет юнит autoscaling"
  value       = aws_launch_template.this.id
}

output "launch_template_name" {
  description = "Имя шаблона"
  value       = aws_launch_template.this.name
}

output "launch_template_latest_version" {
  description = "Номер последней версии шаблона"
  value       = aws_launch_template.this.latest_version
}

output "iam_role_name" {
  description = "Имя IAM-роли инстансов"
  value       = aws_iam_role.this.name
}

output "iam_role_arn" {
  description = "ARN IAM-роли инстансов"
  value       = aws_iam_role.this.arn
}

output "iam_instance_profile_arn" {
  description = "ARN instance profile"
  value       = aws_iam_instance_profile.this.arn
}
