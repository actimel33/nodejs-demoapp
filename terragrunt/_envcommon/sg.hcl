# Security groups: три слоя, каждый принимает трафик только от предыдущего.
#
#   интернет ──80──> ALB ──80──> приложение ──27017──> DocumentDB
#
# Юнит поднимает три группы одним вызовом модуля через несколько экземпляров —
# поэтому здесь source указывает на локальный модуль-обёртку, который
# описывает всю цепочку разом. Модуль лежит в modules/security/.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "../../../modules//security"
}

dependency "vpc" {
  config_path = "../../vpc"

  # Без mock_outputs команда `run --all plan` на пустом месте падает:
  # этот юнит просит у VPC идентификатор, которого ещё нет.
  # Список команд ограничен намеренно — заглушки не должны попасть в apply.
  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id = "vpc-00000000"
  }
}

inputs = {
  name_prefix = "week3-${local.env.environment}"
  vpc_id      = dependency.vpc.outputs.vpc_id
}
