# Три security group одной цепочкой:
#
#   интернет ──80──> ALB ──80──> приложение ──27017──> DocumentDB
#
# Каждый слой принимает трафик ТОЛЬКО от предыдущего, и правило ссылается
# на другую security group, а не на диапазон адресов. Тогда правило не нужно
# править при масштабировании: новый инстанс попадает под него автоматически.
#
# Правила заданы отдельными ресурсами aws_vpc_security_group_*_rule, а не
# inline-блоками. Смешивать нельзя: inline-блоки считают себя единственным
# источником истины и удаляют правила, добавленные отдельными ресурсами.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# --------------------------- ALB ---------------------------

resource "aws_security_group" "alb" {
  # name_prefix, а не name: имена уникальны в VPC, при пересоздании
  # Terraform упрётся в конфликт. Префикс sg- зарезервирован AWS.
  name_prefix = "${var.name_prefix}-alb-"
  description = "Public ALB: HTTP from the internet"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-alb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP from the internet"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "alb_to_app" {
  security_group_id = aws_security_group.alb.id
  description       = "Forward traffic to the app tier"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# ------------------------ приложение ------------------------

resource "aws_security_group" "app" {
  name_prefix = "${var.name_prefix}-app-"
  description = "App tier: HTTP from the ALB only"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-app-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from the public ALB only"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = var.app_port
  to_port                      = var.app_port
  ip_protocol                  = "tcp"
}

# Исходящий трафик сужен вместо разрешённого по умолчанию "всё куда угодно":
# 443 — образ Docker, Secrets Manager, SSM; 80 — репозитории пакетов dnf.
resource "aws_vpc_security_group_egress_rule" "app_https" {
  security_group_id = aws_security_group.app.id
  description       = "HTTPS: container registry, Secrets Manager, SSM"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  to_port     = 443
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_http" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP: dnf package repositories"

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"
}

resource "aws_vpc_security_group_egress_rule" "app_to_docdb" {
  security_group_id = aws_security_group.app.id
  description       = "MongoDB wire protocol to DocumentDB"

  referenced_security_group_id = aws_security_group.docdb.id
  from_port                    = var.docdb_port
  to_port                      = var.docdb_port
  ip_protocol                  = "tcp"
}

# ------------------------ DocumentDB ------------------------

resource "aws_security_group" "docdb" {
  name_prefix = "${var.name_prefix}-docdb-"
  description = "DocumentDB: MongoDB wire protocol from the app tier only"
  vpc_id      = var.vpc_id

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, { Name = "${var.name_prefix}-docdb-sg" })
}

resource "aws_vpc_security_group_ingress_rule" "docdb_from_app" {
  security_group_id = aws_security_group.docdb.id
  description       = "MongoDB wire protocol from the app tier only"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = var.docdb_port
  to_port                      = var.docdb_port
  ip_protocol                  = "tcp"
}
