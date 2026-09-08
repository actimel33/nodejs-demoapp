# ШАБЛОН для main.tf окружения.
#
# Единственный файл в common/, который НЕ подключается симлинком. Причина:
# у dev/ и production/ свой main.tf, а не ссылка,
# потому что ключ состояния в блоке backend у каждого окружения свой,
# а два файла с одинаковым именем в одном каталоге существовать не могут.
#
# В dev/main.tf и production/main.tf лежат настоящие копии этого файла,
# отличающиеся ровно одной строкой — ключом состояния.
#
# Это и есть то самое дублирование, которое схема с симлинками убрать
# не в состоянии.

terraform {
  # 1.10, а не 1.9: с этой версии в бэкенде S3 работает use_lockfile —
  # блокировка состояния без отдельной таблицы DynamoDB.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # backend "s3" { ... }  ← добавляется в копии окружения. dev/main.tf
}

provider "aws" {
  region = var.region

  # Теги на всех ресурсах сразу. По ним ищут забытую
  # инфраструктуру и разбирают счёт в конце месяца.
  default_tags {
    tags = {
      Project     = var.project
      Environment = var.environment
      ManagedBy   = "terraform"
      Owner       = "andrew"
    }
  }
}
