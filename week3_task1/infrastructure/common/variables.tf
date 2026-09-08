# ---------------------------------------------------------------------------
# Базовые
# ---------------------------------------------------------------------------

variable "project" {
  description = "Префикс имени для всех ресурсов"
  type        = string
  default     = "week3"
}

variable "environment" {
  description = "Имя окружения: dev, production или loadtest. Задаётся в env/*.tfvars"
  type        = string

  validation {
    condition     = contains(["dev", "production", "loadtest"], var.environment)
    error_message = "environment должен быть одним из: dev, production, loadtest."
  }
}

variable "region" {
  description = "Регион AWS"
  type        = string
  default     = "eu-central-1"
}

# ---------------------------------------------------------------------------
# Сеть
# ---------------------------------------------------------------------------

variable "vpc_cidr" {
  description = "CIDR всей VPC. У окружений НЕ должен пересекаться — иначе пиринг между ними станет невозможен"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.vpc_cidr))
    error_message = "vpc_cidr должен быть валидным CIDR, например 10.30.0.0/16."
  }
}

variable "public_subnet_cidrs" {
  description = "CIDR публичных подсетей — ровно две, в разных зонах доступности. Здесь живут ALB и инстансы приложения"
  type        = list(string)

  validation {
    condition     = length(var.public_subnet_cidrs) == 2
    error_message = "Нужно ровно две публичные подсети: ALB требует минимум две AZ."
  }
}

variable "private_subnet_cidrs" {
  description = "CIDR приватных подсетей — ровно две. Здесь живёт DocumentDB, интернета у них нет и не нужно"
  type        = list(string)

  validation {
    condition     = length(var.private_subnet_cidrs) == 2
    error_message = "Нужно ровно две приватные подсети: DocumentDB требует минимум две AZ."
  }
}

# ---------------------------------------------------------------------------
# Приложение
# ---------------------------------------------------------------------------

variable "instance_type" {
  description = "Тип инстанса для группы автомасштабирования"
  type        = string
  default     = "t3.micro"
}

variable "asg_min_size" {
  description = "Минимальное число инстансов в группе"
  type        = number
  default     = 1
}

variable "asg_max_size" {
  description = "Максимальное число инстансов. Ограничивает расход при нагрузочном тесте"
  type        = number
  default     = 2
}

variable "asg_desired_capacity" {
  description = "Желаемое число инстансов на старте"
  type        = number
  default     = 1
}

variable "cpu_target_value" {
  description = <<-EOT
    Целевая средняя загрузка CPU в процентах для target tracking policy.
    40% выбрано намеренно низким: чтобы масштабирование сработало быстро
    и его было видно на демонстрации.
  EOT
  type        = number
  default     = 40
}

# ---------------------------------------------------------------------------
# Бонус: оповещения (CloudWatch + SNS)
# ---------------------------------------------------------------------------

variable "enable_notifications" {
  description = "Создавать тему SNS, подписку по почте и алармы CloudWatch"
  type        = bool
  default     = false
}

variable "alert_email" {
  description = "Адрес для оповещений. Подписку нужно подтвердить по ссылке из письма вручную"
  type        = string
  default     = ""

  validation {
    condition     = var.alert_email == "" || can(regex("^[^@ ]+@[^@ ]+\\.[^@ ]+$", var.alert_email))
    error_message = "alert_email должен быть валидным адресом почты либо пустой строкой."
  }
}

# ---------------------------------------------------------------------------
# Task 3: DocumentDB и безопасность
# ---------------------------------------------------------------------------

variable "enable_docdb" {
  description = <<-EOT
    Создавать кластер DocumentDB и подключать к нему приложение.
  EOT
  type        = bool
  default     = false
}

variable "docdb_instance_class" {
  description = "Класс узла DocumentDB. db.t4g.medium — самый дешёвый поддерживаемый"
  type        = string
  default     = "db.t4g.medium"
}

variable "docdb_instance_count" {
  description = "Число узлов кластера. Для стенда 1, для production было бы 2 в разных AZ"
  type        = number
  default     = 1
}

variable "docdb_master_username" {
  description = "Имя главного пользователя базы. Пароль генерирует AWS и хранит в Secrets Manager"
  type        = string
  default     = "appuser"
}

variable "enable_inspector" {
  description = "Включить AWS Inspector для сканирования EC2. Работает на уровне всего аккаунта"
  type        = bool
  default     = false
}

# ---------------------------------------------------------------------------
# Вычисляемые значения
# ---------------------------------------------------------------------------
# Живут рядом с переменными намеренно: main.tf у каждого окружения свой
# (в нём блок backend), поэтому общие locals должны лежать в файле,
# который подключается симлинком.

locals {
  name_prefix = "${var.project}-${var.environment}"

  # Ровно две зоны: ALB требует минимум две подсети в разных AZ,
  # DocumentDB — тоже минимум две.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  # Значения появляются только когда включён DocumentDB (var.enable_docdb).
  # Пустая строка — сигнал для user_data.sh пропустить блок подключения к базе.
  docdb_endpoint   = var.enable_docdb ? aws_docdb_cluster.main[0].endpoint : ""
  docdb_secret_arn = var.enable_docdb ? aws_docdb_cluster.main[0].master_user_secret[0].secret_arn : ""
}
