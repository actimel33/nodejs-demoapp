variable "name" {
  description = "Базовое имя, например week3-dev"
  type        = string
}

variable "autoscaling_group_name" {
  description = "Имя группы, за событиями которой следим"
  type        = string
}

variable "alb_arn_suffix" {
  description = "Суффикс ARN балансировщика — измерение метрики TargetResponseTime"
  type        = string
  default     = ""
}

variable "alert_email" {
  description = <<-EOT
    Адрес для оповещений. Пустая строка — тема создаётся, подписки нет.
    В репозитории не хранится: передаётся при применении через
    -var 'alert_email=...' либо переменной окружения TF_VAR_alert_email.
  EOT
  type        = string
  default     = ""
}

variable "cpu_alarm_threshold" {
  description = "Порог аларма по средней загрузке CPU, процентов"
  type        = number
  default     = 70
}

variable "latency_alarm_threshold" {
  description = "Порог аларма по времени ответа целей, секунд"
  type        = number
  default     = 3
}

variable "tags" {
  description = "Дополнительные теги"
  type        = map(string)
  default     = {}
}
