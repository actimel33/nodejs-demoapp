# Оповещения: тема SNS, подписка, уведомления группы и алармы.
#
# Юнит последний в графе — ему нужны и имя группы, и суффикс ARN
# балансировщика. Зато его можно менять, не трогая ничего ниже: пороги
# подкручивают чаще, чем инфраструктуру.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "../../../modules//cloudwatch"
}

dependency "autoscaling" {
  config_path = "../autoscaling"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    autoscaling_group_name = "mock-asg"
  }
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    arn_suffix = "app/mock/0000000000000000"
  }
}

inputs = {
  name                   = "week3-${local.env.environment}"
  autoscaling_group_name = dependency.autoscaling.outputs.autoscaling_group_name
  alb_arn_suffix         = dependency.alb.outputs.arn_suffix

  # Адрес в репозитории не хранится — форк публичный, а адреса с GitHub
  # собирают боты. Передаётся при применении:
  #   terragrunt apply -- -var 'alert_email=твой@адрес'
  # либо через переменную окружения TF_VAR_alert_email.
  alert_email = get_env("TF_VAR_alert_email", "")
}
