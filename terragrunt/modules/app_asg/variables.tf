variable "name" {
  description = "Базовое имя, например week3-dev"
  type        = string
}

variable "launch_template_id" {
  description = "ID шаблона запуска — приходит из юнита ec2"
  type        = string
}

variable "launch_template_version" {
  description = "Версия шаблона. $Latest означает, что новые инстансы берут свежую версию"
  type        = string
  default     = "$Latest"
}

variable "vpc_zone_identifier" {
  description = "Подсети, в которых группа поднимает инстансы"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN target group балансировщика"
  type        = string
}

variable "min_size" {
  description = "Минимальное число инстансов"
  type        = number
}

variable "max_size" {
  description = "Максимальное число инстансов"
  type        = number
}

variable "desired_capacity" {
  description = "Желаемое число инстансов на старте"
  type        = number
}

variable "cpu_target_value" {
  description = "Целевая средняя загрузка CPU в процентах для target tracking"
  type        = number
  default     = 40
}

variable "health_check_grace_period" {
  description = "Сколько секунд после запуска не проверять здоровье: запас на загрузку ОС, установку Docker и скачивание образа"
  type        = number
  default     = 180
}

variable "tags" {
  description = "Дополнительные теги"
  type        = map(string)
  default     = {}
}
