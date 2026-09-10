# Группа автомасштабирования — «сколько инстансов и где».
# Шаблон запуска приходит из юнита ec2, поэтому здесь остались только
# границы группы и политика масштабирования.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "../../../modules//app_asg"
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    public_subnets = ["subnet-00000000", "subnet-11111111"]
  }
}

dependency "ec2" {
  config_path = "../ec2"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    launch_template_id = "lt-00000000000000000"
  }
}

dependency "alb" {
  config_path = "../alb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    target_groups = {
      demoapp = { arn = "arn:aws:elasticloadbalancing:eu-central-1:000000000000:targetgroup/mock/0000000000000000" }
    }
  }
}

inputs = {
  name = "week3-${local.env.environment}"

  launch_template_id = dependency.ec2.outputs.launch_template_id

  vpc_zone_identifier = dependency.vpc.outputs.public_subnets
  target_group_arn    = dependency.alb.outputs.target_groups["demoapp"].arn

  min_size         = local.env.asg_min_size
  max_size         = local.env.asg_max_size
  desired_capacity = local.env.asg_desired_capacity
  cpu_target_value = local.env.cpu_target_value
}
