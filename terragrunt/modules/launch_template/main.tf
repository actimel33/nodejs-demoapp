# Launch template — «рецепт инстанса»: какой образ, какой тип, какие security
# groups, какой user data, под какой ролью.
#
# Вынесен в отдельный юнит, потому что структура задания разделяет ec2
# и autoscaling. Разделение осмысленно и по сути: шаблон отвечает на вопрос
# «какая машина», группа — «сколько их и где». Меняются они по разным поводам
# и с разной частотой: правка user data трогает шаблон, изменение потолка
# нагрузки — группу.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# Свежая AMI Amazon Linux 2023 из публичного параметра SSM.
# Лучше захардкоженного ami-xxxxx: тот протухает и различается между регионами.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------------------------------------------------------------------------
# Роль инстанса
# ---------------------------------------------------------------------------
# Роль вместо ключей доступа: инстанс получает временные учётные данные через
# метаданные, SDK и CLI находят их сами.

resource "aws_iam_role" "this" {
  name = "${var.name}-app"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

# SSM нужен сразу для трёх вещей: заход на инстанс без SSH через Session
# Manager, сбор инвентаря и сканирование AWS Inspector.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.this.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Право прочитать один секрет с паролем базы. Политику создаёт модуль docdb,
# здесь она только прицепляется — и только если база вообще есть.
resource "aws_iam_role_policy_attachment" "docdb_secret" {
  count = var.docdb_secret_policy_arn != "" ? 1 : 0

  role       = aws_iam_role.this.name
  policy_arn = var.docdb_secret_policy_arn
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name}-app"
  role = aws_iam_role.this.name

  tags = var.tags
}

# ---------------------------------------------------------------------------
# Шаблон запуска
# ---------------------------------------------------------------------------

resource "aws_launch_template" "this" {
  name_prefix = "${var.name}-app-"
  description = "Application instance: Amazon Linux 2023 running nodejs-demoapp in Docker"

  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  vpc_security_group_ids = var.security_group_ids

  iam_instance_profile {
    arn = aws_iam_instance_profile.this.arn
  }

  # user_data выполняется cloud-init от root ТОЛЬКО при первом старте.
  # Правка шаблона не трогает работающие инстансы — нужен instance refresh.
  user_data = base64encode(templatefile(var.user_data_path, {
    environment     = var.name
    aws_region      = var.region
    docdb_endpoint  = var.docdb_endpoint
    docdb_secret_id = var.docdb_secret_arn
  }))

  # IMDSv2 обязателен: без токена метаданные не отдаются, что закрывает
  # целый класс атак через SSRF.
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-app" })
  }

  # Новая версия шаблона создаётся до удаления старой: группа может
  # ссылаться на текущую в момент применения.
  lifecycle {
    create_before_destroy = true
  }

  tags = var.tags
}
