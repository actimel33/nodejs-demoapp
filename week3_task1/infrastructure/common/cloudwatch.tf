# Алармы CloudWatch (бонусная часть Task 1).
#
# Аларм и уведомление группы автомасштабирования — РАЗНЫЕ вещи, и в отчёте
# стоит показать оба: письмо о запуске инстанса доказывает, что масштабирование
# сработало, а аларм показывает, по какому сигналу это произошло.
#
# Отдельно: target tracking policy заводит СВОИ алармы автоматически, они будут
# видны в консоли рядом.

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = var.enable_notifications ? 1 : 0

  alarm_name        = "${local.name_prefix}-asg-high-cpu"
  alarm_description = "Average CPU across the ASG stayed above 70% for two minutes"

  namespace   = "AWS/EC2"
  metric_name = "CPUUtilization"
  statistic   = "Average"

  period              = 60
  evaluation_periods  = 2
  threshold           = 70
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    AutoScalingGroupName = module.asg.autoscaling_group_name
  }

  # ok_actions не менее полезен, чем alarm_actions: оповещение только
  # о срабатывании оставляет в неведении, закончилась проблема или нет.
  alarm_actions = [aws_sns_topic.scaling_events[0].arn]
  ok_actions    = [aws_sns_topic.scaling_events[0].arn]

  # Группа может уменьшиться до нуля инстансов, и тогда данных по метрике
  # не будет. По умолчанию (missing) состояние аларма не изменится и он
  # навсегда зависнет в ALARM.
  treat_missing_data = "notBreaching"
}

# Время ответа балансировщика. Метрика показывает,
# что видит пользователь, а не что происходит внутри.
resource "aws_cloudwatch_metric_alarm" "high_latency" {
  count = var.enable_notifications ? 1 : 0

  alarm_name        = "${local.name_prefix}-alb-high-latency"
  alarm_description = "ALB target response time above 3 seconds"

  namespace   = "AWS/ApplicationELB"
  metric_name = "TargetResponseTime"
  statistic   = "Average"

  period              = 60
  evaluation_periods  = 2
  threshold           = 3
  comparison_operator = "GreaterThanThreshold"

  dimensions = {
    LoadBalancer = module.alb.arn_suffix
  }

  alarm_actions      = [aws_sns_topic.scaling_events[0].arn]
  ok_actions         = [aws_sns_topic.scaling_events[0].arn]
  treat_missing_data = "notBreaching"
}
