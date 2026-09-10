# Группа автомасштабирования. Отвечает на вопрос «сколько инстансов и где»,
# тогда как launch template из юнита ec2 отвечает на «какая машина».
#
# Шаблон сюда приходит готовым через dependency, поэтому у модуля
# terraform-aws-modules/autoscaling выключено его создание.

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

module "asg" {
  source  = "terraform-aws-modules/autoscaling/aws"
  version = "~> 9.3"

  name = "${var.name}-asg"

  # Шаблон создаёт отдельный юнит, здесь только ссылка на него.
  create_launch_template  = false
  launch_template_id      = var.launch_template_id
  launch_template_version = var.launch_template_version

  vpc_zone_identifier = var.vpc_zone_identifier

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  # ELB, а не дефолтный EC2: при EC2 группа считает здоровой машину
  # с упавшим контейнером — виртуалка-то запущена.
  health_check_type         = "ELB"
  health_check_grace_period = var.health_check_grace_period

  # До версии 8.x аргумент назывался target_group_arns — он УДАЛЁН.
  traffic_source_attachments = {
    alb = {
      traffic_source_identifier = var.target_group_arn
      traffic_source_type       = "elbv2"
    }
  }

  # Метрики группы надо включать явно: по умолчанию список пустой,
  # и график «сколько инстансов в строю» окажется пустым.
  enabled_metrics = [
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

  tags = var.tags
}
