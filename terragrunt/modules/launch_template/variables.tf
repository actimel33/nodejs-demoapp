variable "name" {
  description = "Базовое имя, например week3-dev"
  type        = string
}

variable "region" {
  description = "Регион — попадает в user_data для вызова AWS CLI"
  type        = string
}

variable "user_data_path" {
  description = "Путь к шаблону user_data.sh"
  type        = string
}

variable "instance_type" {
  description = "Тип инстанса"
  type        = string
  default     = "t3.micro"
}

variable "security_group_ids" {
  description = "Группы для инстансов приложения"
  type        = list(string)
}

variable "docdb_endpoint" {
  description = "Адрес кластера DocumentDB. Пустая строка — блок подключения в user_data пропускается"
  type        = string
  default     = ""
}

variable "docdb_secret_arn" {
  description = "ARN секрета с паролем DocumentDB"
  type        = string
  default     = ""
}

variable "docdb_secret_policy_arn" {
  description = "ARN политики на чтение секрета. Пустая строка — политика не прицепляется"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Дополнительные теги"
  type        = map(string)
  default     = {}
}
