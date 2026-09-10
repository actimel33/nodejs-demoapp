# Кластер Amazon DocumentDB — MongoDB-совместимая управляемая база.
#
# Модуль охватывает кластер целиком как одну сущность: подсети, кластер, узлы
# и IAM-политику на чтение пароля. Именно эта граница делает его модулем,
# а не обёрткой ради обёртки.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_docdb_subnet_group" "this" {
  name       = "${var.name}-docdb"
  subnet_ids = var.subnet_ids

  tags = merge(var.tags, { Name = "${var.name}-docdb-subnets" })
}

resource "aws_docdb_cluster" "this" {
  cluster_identifier = "${var.name}-docdb"
  engine             = "docdb"

  master_username = var.master_username

  # Пароль генерирует и хранит AWS в Secrets Manager.
  #
  # Документация провайдера предупреждает прямым текстом: ВСЕ аргументы,
  # включая master_password, сохраняются в state ОТКРЫТЫМ ТЕКСТОМ.
  # Здесь наружу отдаётся только ARN секрета.
  manage_master_user_password = true

  db_subnet_group_name   = aws_docdb_subnet_group.this.name
  vpc_security_group_ids = var.security_group_ids

  # Шифрование на диске: стоит ноль, а его отсутствие — готовая находка
  # в любом аудите.
  storage_encrypted = true

  deletion_protection     = var.deletion_protection
  skip_final_snapshot     = var.skip_final_snapshot
  backup_retention_period = var.backup_retention_period

  tags = merge(var.tags, { Name = "${var.name}-docdb" })
}

resource "aws_docdb_cluster_instance" "this" {
  count = var.instance_count

  identifier         = "${var.name}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.this.id
  instance_class     = var.instance_class

  tags = merge(var.tags, { Name = "${var.name}-docdb-${count.index}" })
}

# Политика на чтение ОДНОГО секрета.
#
# У DocumentDB НЕТ аутентификации через IAM: действия docdb:Connect
# не существует, и никакая политика не пустит и не остановит запрос
# к порту 27017 — это работа security group. IAM контролирует доступ
# к ПАРОЛЮ, а не к базе.
#
# Resource с конкретным ARN, а не "*": утечка роли даёт пароль от одной базы,
# а не все секреты аккаунта.
resource "aws_iam_policy" "read_secret" {
  count = var.create_secret_read_policy ? 1 : 0

  name        = "${var.name}-read-docdb-secret"
  description = "Allows reading the DocumentDB master password from Secrets Manager"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [aws_docdb_cluster.this.master_user_secret[0].secret_arn]
    }]
  })

  tags = var.tags
}
