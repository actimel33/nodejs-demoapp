# Amazon DocumentDB — база для раздела /todo приложения (Task 3).
#
# Создаётся только при enable_docdb = true.
# это самая дорогая позиция недели, около $0.09/час за узел ($2.1 в сутки).
#
# Приложение уже умеет MongoDB: в src/todo/routes.mjs есть мини-приложение
# «список задач», которое включается само при наличии переменной окружения
# TODO_MONGO_CONNSTR.

# Подсети, в которых живёт кластер. Минимум две зоны доступности —
# это требование сервиса.
resource "aws_docdb_subnet_group" "main" {
  count = var.enable_docdb ? 1 : 0

  name       = "${local.name_prefix}-docdb"
  subnet_ids = [for s in aws_subnet.private : s.id]

  tags = { Name = "${local.name_prefix}-docdb-subnets" }
}

resource "aws_docdb_cluster" "main" {
  count = var.enable_docdb ? 1 : 0

  cluster_identifier = "${local.name_prefix}-docdb"
  engine             = "docdb"

  master_username = var.docdb_master_username

  # Пароль генерирует и хранит AWS в Secrets Manager.
  #
  # Документация провайдера предупреждает прямым текстом: ВСЕ аргументы,
  # включая master_password, сохраняются в state ОТКРЫТЫМ ТЕКСТОМ. Вариант
  # с паролем в переменной означает пароль в state, а часто ещё и в tfvars
  # рядом с кодом. Здесь наружу отдаётся только ARN секрета, а инстанс
  # читает его сам по своей IAM-роли.
  manage_master_user_password = true

  db_subnet_group_name   = aws_docdb_subnet_group.main[0].name
  vpc_security_group_ids = [aws_security_group.docdb[0].id]

  # Шифрование на диске. Стоит ноль, а его отсутствие — готовая находка
  # в любом аудите безопасности.
  storage_encrypted = true

  # Учебный стенд: без этих двух строк terraform destroy не пройдёт,
  # В production: deletion_protection = true.
  deletion_protection = false
  skip_final_snapshot = true

  backup_retention_period = 1

  tags = { Name = "${local.name_prefix}-docdb" }
}

resource "aws_docdb_cluster_instance" "main" {
  count = var.enable_docdb ? var.docdb_instance_count : 0

  identifier         = "${local.name_prefix}-docdb-${count.index}"
  cluster_identifier = aws_docdb_cluster.main[0].id
  instance_class     = var.docdb_instance_class

  tags = { Name = "${local.name_prefix}-docdb-${count.index}" }
}
