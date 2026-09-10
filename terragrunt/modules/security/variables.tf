variable "name_prefix" {
  description = "Префикс имени групп, например week3-dev"
  type        = string
}

variable "vpc_id" {
  description = "ID VPC, в которой создаются группы"
  type        = string
}

variable "app_port" {
  description = "Порт, на котором приложение слушает на инстансе"
  type        = number
  default     = 80
}

variable "docdb_port" {
  description = "Порт DocumentDB"
  type        = number
  default     = 27017
}

variable "tags" {
  description = "Дополнительные теги"
  type        = map(string)
  default     = {}
}
