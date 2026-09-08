# НАСТОЯЩИЙ файл, а не симлинк — единственный такой в каталоге окружения.
#
# Причина: ключ состояния в блоке backend у каждого окружения свой.
# Одинаковый ключ означал бы, что второе окружение переписывает первое.
# Символической ссылкой этого не выразить: два файла с именем main.tf
# в одном каталоге существовать не могут.
#
# Содержимое — копия common/main.tf плюс блок backend. Это единственное
# дублирование, которое схема с симлинками убрать не в состоянии:
# правку провайдера или версий придётся внести в оба окружения руками.
#
# ЗАМЕНИТЬ имя бакета на своё перед первым terraform init.

terraform {
  # 1.10, а не 1.9: с этой версии в бэкенде S3 работает use_lockfile —
  # блокировка состояния без отдельной таблицы DynamoDB, а dynamodb_table
  # в документации помечен устаревшим.
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket       = "itsyndicate-tfstate-andrew"
    key          = "week3/production/terraform.tfstate"
    region       = "eu-central-1"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.region

  # Теги на всех ресурсах сразу. Это не косметика: по ним ищут забытую
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
