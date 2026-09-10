variable "name" {
  description = "Базовое имя кластера и связанных ресурсов, например week3-dev"
  type        = string
}

variable "subnet_ids" {
  description = "Приватные подсети — минимум две в разных зонах доступности, это требование сервиса"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "DocumentDB требует минимум две подсети в разных AZ."
  }
}

variable "security_group_ids" {
  description = "Группы, которые вешаются на кластер"
  type        = list(string)
}

variable "master_username" {
  description = "Имя главного пользователя. Пароль генерирует AWS и хранит в Secrets Manager"
  type        = string
  default     = "appuser"
}

variable "instance_class" {
  description = "Класс узла. db.t4g.medium — самый дешёвый поддерживаемый, $0.08924/час в eu-central-1"
  type        = string
  default     = "db.t4g.medium"
}

variable "instance_count" {
  description = "Число узлов. 1 для стенда, 2 в разных AZ для production"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_count >= 1 && var.instance_count <= 3
    error_message = "instance_count должен быть от 1 до 3: больше для учебной задачи не нужно и дорого."
  }
}

variable "backup_retention_period" {
  description = "Сколько дней хранить бэкапы"
  type        = number
  default     = 1
}

variable "deletion_protection" {
  description = "Защита от удаления. Для учебного стенда false, иначе destroy не пройдёт"
  type        = bool
  default     = false
}

variable "skip_final_snapshot" {
  description = "Не делать снапшот при удалении. Для стенда true"
  type        = bool
  default     = true
}

variable "create_secret_read_policy" {
  description = "Создать IAM-политику на чтение секрета с паролем — её прицепляют к роли инстансов"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Дополнительные теги"
  type        = map(string)
  default     = {}
}
