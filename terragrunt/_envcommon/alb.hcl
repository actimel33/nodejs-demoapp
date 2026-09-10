locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "tfr:///terraform-aws-modules/alb/aws//?version=10.5.1"
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    vpc_id         = "vpc-00000000"
    public_subnets = ["subnet-00000000", "subnet-11111111"]
  }
}

dependency "sg" {
  config_path = "../sg"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    alb_security_group_id = "sg-00000000"
  }
}

inputs = {
  name    = "week3-${local.env.environment}-public-alb"
  vpc_id  = dependency.vpc.outputs.vpc_id
  subnets = dependency.vpc.outputs.public_subnets

  # Ловушка модуля 10.x: по умолчанию true, и destroy упрётся в защиту
  # от удаления ровно тогда, когда захочешь перестать платить.
  enable_deletion_protection = false

  create_security_group = false
  security_groups       = [dependency.sg.outputs.alb_security_group_id]

  target_groups = {
    demoapp = {
      name_prefix = "app-"
      protocol    = "HTTP"
      port        = 80
      target_type = "instance"

      # Вторая ловушка 10.x: по умолчанию true, модуль потребует target_id.
      # Цели регистрирует группа автомасштабирования.
      create_attachment = false

      health_check = {
        enabled  = true
        path     = "/"
        protocol = "HTTP"
        matcher  = "200"

        # Пороги терпимые: /tools/load блокирует event loop Node.js,
        # на строгих настройках группа начнёт убивать инстансы под нагрузкой.
        interval            = 30
        timeout             = 10
        healthy_threshold   = 2
        unhealthy_threshold = 5
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
}
