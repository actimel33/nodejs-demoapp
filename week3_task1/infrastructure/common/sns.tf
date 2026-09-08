# Оповещения о событиях масштабирования (бонусная часть Task 1).
#
# ВАЖНО: подписку по почте нужно подтвердить ВРУЧНУЮ по ссылке из письма.
# Terraform это состояние не отслеживает и не ждёт: apply завершится успешно,
# а письма приходить не будут. Проверка — в консоли SNS у подписки должен
# быть ARN, а не слово PendingConfirmation.

resource "aws_sns_topic" "scaling_events" {
  count = var.enable_notifications ? 1 : 0

  name = "${local.name_prefix}-scaling-events"

  tags = { Name = "${local.name_prefix}-scaling-events" }
}

resource "aws_sns_topic_subscription" "email" {
  count = var.enable_notifications && var.alert_email != "" ? 1 : 0

  topic_arn = aws_sns_topic.scaling_events[0].arn
  protocol  = "email"
  endpoint  = var.alert_email

  # Сколько минут Terraform ждёт подтверждения, прежде чем записать подписку
  # как pending_confirmation. Умолчание провайдера — одна минута, за неё
  # редко успеваешь открыть почту; десять удобнее.
  #
  # ВАЖНО, ЧЕГО ЭТО НЕ РЕШАЕТ: подписку можно убить из почтового клиента —
  # ссылкой «unsubscribe» в подвале письма или кнопкой «Отписаться».
  # Такое удаление проходит
  # мимо IAM и не видно в CloudTrail, а Terraform узнаёт о нём только
  # на следующем plan. В письме нужна ровно одна ссылка — Confirm subscription.
  confirmation_timeout_in_minutes = 10
}

# Уведомления ОТ САМОЙ ГРУППЫ автомасштабирования: «инстанс запущен»,
# «инстанс завершён». Это ответ на вопрос «что произошло», в отличие от
# аларма CloudWatch, который отвечает на «почему это может произойти».
#
# События *_ERROR добавлены не для полноты: провалившийся запуск — ровно тот
# случай, когда нужно узнать сразу. Цикл «создал — не прошёл health check —
# убил — создал» без оповещений выглядит как тишина.
resource "aws_autoscaling_notification" "scaling" {
  count = var.enable_notifications ? 1 : 0

  group_names = [module.asg.autoscaling_group_name]
  topic_arn   = aws_sns_topic.scaling_events[0].arn

  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
}
