# Оповещения о событиях масштабирования: тема SNS, подписка, уведомления
# группы и алармы CloudWatch.
#
# Вынесено в отдельный юнит по структуре задания: наблюдение
# меняется чаще инфраструктуры — пороги подкручивают, адреса добавляют.
#
# Уведомление группы и аларм — РАЗНЫЕ вещи. Первое отвечает на вопрос
# «что произошло» (инстанс запущен, инстанс завершён), второе — «почему это
# может произойти» (нагрузка выше порога).

terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

resource "aws_sns_topic" "this" {
  name = "${var.name}-scaling-events"

  tags = merge(var.tags, { Name = "${var.name}-scaling-events" })
}

# ВАЖНО: подписку по почте нужно подтвердить вручную по ссылке из письма.
# Terraform это состояние не отслеживает — apply завершится успешно, а письма
# приходить не будут, пока не нажмёшь Confirm subscription.
#
# Отдельная ловушка: подписку можно убить из почтового клиента — ссылкой
# unsubscribe или кнопкой «Отписаться». Такое удаление проходит мимо IAM, не видно
# в CloudTrail, и Terraform его не замечает: SNS помечает подписку Deleted,
# но не убирает, поэтому plan показывает «no changes». Лечится только явным
# terragrunt apply -replace.
resource "aws_sns_topic_subscription" "email" {
  count = var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.this.arn
  protocol  = "email"
  endpoint  = var.alert_email

  # Умолчание провайдера — одна минута, за неё редко успеваешь открыть почту.
  confirmation_timeout_in_minutes = 10
}

# События самой группы. Ошибочные (*_ERROR) включены не для полноты:
# провалившийся запуск — ровно тот случай, когда нужно узнать сразу.
# Цикл «создал — не прошёл health check — убил — создал» без оповещений
# выглядит как тишина.
resource "aws_autoscaling_notification" "this" {
  group_names = [var.autoscaling_group_name]
  topic_arn   = aws_sns_topic.this.arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}

# Аларм тревоги, а не управления. Порог выше цели политики масштабирования
# намеренно: пока система справляется сама, человека будить незачем.
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name        = "${var.name}-asg-high-cpu"
  alarm_description = "Average CPU across the ASG stayed above the threshold"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  period              = 60
  evaluation_periods  = 2
  threshold           = var.cpu_alarm_threshold
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = var.autoscaling_group_name
  }

  alarm_actions = [aws_sns_topic.this.arn]
  ok_actions    = [aws_sns_topic.this.arn]

  # Группа может уменьшиться до нуля инстансов, и тогда данных по метрике
  # не будет. По умолчанию (missing) аларм навсегда зависнет в ALARM.
  treat_missing_data = "notBreaching"

  tags = var.tags
}

# Время ответа полезнее CPU: оно показывает, что видит пользователь.
# На нагрузочном тесте именно этот аларм сработал первым — процессор был
# загружен на 43%, а запросы ждали по 4 секунды.
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.alb_arn_suffix != "" ? 1 : 0

  alarm_name        = "${var.name}-alb-high-latency"
  alarm_description = "ALB target response time above the threshold"

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"
  statistic   = "Average"

  period              = 60
  evaluation_periods  = 2
  threshold           = var.latency_alarm_threshold
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = var.alb_arn_suffix
  }

  alarm_actions      = [aws_sns_topic.this.arn]
  ok_actions         = [aws_sns_topic.this.arn]
  treat_missing_data = "notBreaching"

  tags = var.tags
}
