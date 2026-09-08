# Три группы, три слоя. Приём, ради которого всё затевается: правило ссылается
# на ДРУГУЮ security group, а не на диапазон адресов. Тогда правило не нужно
# править при масштабировании — новый инстанс попадает под него автоматически,
# просто потому что состоит в нужной группе.
#
#   интернет ──80──> ALB ──80──> приложение ──27017──> DocumentDB
#
# Правила заданы отдельными ресурсами aws_vpc_security_group_*_rule, а не
# inline-блоками ingress/egress. Смешивать эти два способа нельзя: inline-блоки
# считают себя единственным источником истины и при следующем apply удаляют
# правила, добавленные отдельными ресурсами.

# ---------------------------------------------------------------------------
# Балансировщик: принимает 80 из интернета — он для этого и существует
# ---------------------------------------------------------------------------

# Свежая AMI Amazon Linux 2023 из публичного параметра SSM.
# Так лучше, чем захардкоженный ami-xxxxx: тот протухает и различается
# между регионами, а этот всегда указывает на актуальный образ.
data "aws_ssm_parameter" "al2023" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

resource "aws_security_group" "alb" {
  # name_prefix, а не name: имена SG уникальны в VPC, и при пересоздании
  # Terraform упрётся в конфликт имён. Префикс sg- зарезервирован AWS.
  name_prefix = "${local.name_prefix}-alb-"
  description = "Public ALB: HTTP from the internet"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-alb-sg" }
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
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# ---------------------------------------------------------------------------
# Приложение: принимает 80 ТОЛЬКО от группы балансировщика
# ---------------------------------------------------------------------------

resource "aws_security_group" "app" {
  name_prefix = "${local.name_prefix}-app-"
  description = "App tier: HTTP from the ALB only"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-app-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "app_from_alb" {
  security_group_id = aws_security_group.app.id
  description       = "HTTP from the public ALB only"

  referenced_security_group_id = aws_security_group.alb.id
  from_port                    = 80
  to_port                      = 80
  ip_protocol                  = "tcp"
}

# Исходящий трафик сужен вместо разрешённого по умолчанию "всё куда угодно".
# 443 нужен для скачивания образа Docker и вызова Secrets Manager,
# 80 — для репозиториев пакетов dnf.
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
  count = var.enable_docdb ? 1 : 0

  security_group_id = aws_security_group.app.id
  description       = "MongoDB wire protocol to DocumentDB"

  referenced_security_group_id = aws_security_group.docdb[0].id
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
}

# ---------------------------------------------------------------------------
# DocumentDB: принимает 27017 ТОЛЬКО от группы приложения
# ---------------------------------------------------------------------------

resource "aws_security_group" "docdb" {
  count = var.enable_docdb ? 1 : 0

  name_prefix = "${local.name_prefix}-docdb-"
  description = "DocumentDB: MongoDB wire protocol from the app tier only"
  vpc_id      = aws_vpc.main.id

  lifecycle {
    create_before_destroy = true
  }

  tags = { Name = "${local.name_prefix}-docdb-sg" }
}

resource "aws_vpc_security_group_ingress_rule" "docdb_from_app" {
  count = var.enable_docdb ? 1 : 0

  security_group_id = aws_security_group.docdb[0].id
  description       = "MongoDB wire protocol from the app tier only"

  referenced_security_group_id = aws_security_group.app.id
  from_port                    = 27017
  to_port                      = 27017
  ip_protocol                  = "tcp"
}

# ===========================================================================
# IAM: роль инстанса
# ===========================================================================
#
# Инстанс получает ВРЕМЕННЫЕ учётные данные через
# метаданные, SDK и CLI находят их сами — ничего настраивать в приложении не
# нужно и никаких ключей в user data.
#
# Роль и instance profile создаёт модуль autoscaling (create_iam_instance_profile),
# здесь описаны только политики, которые к ней прицепляются.

# Политика на чтение ОДНОГО секрета с паролем DocumentDB.
#
# У DocumentDB НЕТ аутентификации через
# IAM: действия docdb:Connect не существует, и никакая политика не пустит и не
# остановит запрос к порту 27017 — это работа security group. IAM контролирует
# доступ к ПАРОЛЮ, а не к базе.
#
# Resource с конкретным ARN, а не "*": утечка роли даёт пароль от одной базы,
# а не все секреты аккаунта.
resource "aws_iam_policy" "read_docdb_secret" {
  count = var.enable_docdb ? 1 : 0

  name        = "${local.name_prefix}-read-docdb-secret"
  description = "Allows the app instances to read the DocumentDB master password"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = [local.docdb_secret_arn]
    }]
  })
}

# ===========================================================================
# Балансировщик и target group
# ===========================================================================

module "alb" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 10.5"

  name    = "${local.name_prefix}-public-alb"
  vpc_id  = aws_vpc.main.id
  subnets = [for s in aws_subnet.public : s.id]

  # ЛОВУШКА 1 модуля 10.x: по умолчанию true, и тогда terraform destroy
  # упрётся в защиту от удаления — самая обидная ошибка, потому что
  # обнаруживается ровно в момент, когда хочешь перестать платить.
  enable_deletion_protection = false

  # Группу мы создали сами выше, модулю свою создавать не нужно.
  create_security_group = false
  security_groups       = [aws_security_group.alb.id]

  target_groups = {
    demoapp = {
      name_prefix = "app-" # максимум 6 символов
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"

      # ЛОВУШКА 2 модуля 10.x: по умолчанию true, и модуль попытается
      # зарегистрировать цель сам, требуя target_id. Цели регистрирует
      # группа автомасштабирования, поэтому здесь false.
      create_attachment = false

      health_check = {
        enabled  = true
        path     = "/"
        protocol = "HTTP"
        matcher  = "200"

        # Пороги намеренно терпимые. Эндпоинт /tools/load блокирует event loop
        # Node.js целиком, и на строгих настройках группа начнёт убивать
        # инстансы прямо во время нагрузочного теста.
        #
        # 10, а не 5: 10 неудачных проверок × 30 секунд = 300 секунд, которые
        # инстанс может не отвечать и остаться в строю. Это проверено на
        # практике — при пороге 5 (150 секунд) группа заменила три инстанса
        # подряд во время теста, и политика масштабирования не успевала
        # отреагировать: метрика обнулялась вместе с убитой машиной.
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 10
      }
    }
  }

  listeners = {
    http = {
      port     = 80
      protocol = "HTTP"

      forward = {
        target_group_key = "demoapp"
      }
    }
  }

  tags = { Name = "${local.name_prefix}-public-alb" }
}

# ===========================================================================
# Launch template и группа автомасштабирования
# ===========================================================================

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.3"

  name = "${local.name_prefix}-asg"

  image_id      = data.aws_ssm_parameter.al2023.value
  instance_type = var.instance_type

  # Модуль ждёт УЖЕ закодированную в base64 строку.
  # templatefile подставляет переменные в скрипт: пустой docdb_endpoint
  # означает, что блок подключения к базе внутри скрипта будет пропущен.
  user_data = base64encode(templatefile("${path.module}/../../user_data/user_data.sh", {
    environment     = var.environment
    aws_region      = var.region
    docdb_endpoint  = local.docdb_endpoint
    docdb_secret_id = local.docdb_secret_arn
  }))

  security_groups     = [aws_security_group.app.id]
  vpc_zone_identifier = [for s in aws_subnet.public : s.id]

  min_size         = var.asg_min_size
  max_size         = var.asg_max_size
  desired_capacity = var.asg_desired_capacity

  # ELB, а не дефолтный EC2. При EC2 группа считает здоровой машину с упавшим
  # контейнером: виртуалка-то запущена. При ELB она доверяет проверкам
  # балансировщика и заменяет инстанс, переставший отвечать по HTTP.
  health_check_type = "ELB"

  # Запас на загрузку ОС, установку Docker и скачивание образа. Слишком малое
  # значение даёт цикл «создал — убил — создал».
  health_check_grace_period = 180

  # Привязка к target group. В версиях модуля до 8.x это назывался
  # target_group_arns — аргумент УДАЛЁН.
  traffic_source_attachments = {
    alb = {
      traffic_source_identifier = module.alb.target_groups["demoapp"].arn
      traffic_source_type       = "elbv2"
    }
  }

  # Роль и instance profile создаёт модуль.
  # AmazonSSMManagedInstanceCore нужен сразу для трёх вещей: заход на инстанс
  # без SSH через Session Manager, сбор инвентаря и сканирование AWS Inspector.
  create_iam_instance_profile = true
  iam_role_name               = "${local.name_prefix}-app"
  iam_role_policies = merge(
    { ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore" },
    var.enable_docdb ? { docdb_secret = aws_iam_policy.read_docdb_secret[0].arn } : {}
  )

  # Метрики группы надо включать ЯВНО: по умолчанию список пустой, и график
  # «сколько инстансов в строю» окажется пустым ровно тогда, когда понадобится
  # для отчёта.
  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances",
  ]

  scaling_policies = {
    cpu-target = {
      policy_type = "TargetTrackingScaling"

      target_tracking_configuration = {
        predefined_metric_specification = {
          predefined_metric_type = "ASGAverageCPUUtilization"
        }
        target_value = var.cpu_target_value
      }
    }
  }

  instance_name = "${local.name_prefix}-app"

  tags = { Name = "${local.name_prefix}-asg" }
}
