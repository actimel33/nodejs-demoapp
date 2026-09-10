# Launch template — «рецепт инстанса». Отдельный юнит по структуре задания,
# и разделение осмысленно: шаблон меняется при правке user data или смены
# образа, группа — при изменении потолка нагрузки. Разные поводы, разная
# частота, разные состояния.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "../../../modules//launch_template"
}

dependency "sg" {
  config_path = "../sg"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    app_security_group_id = "sg-00000000"
  }
}

dependency "docdb" {
  config_path = "../docdb"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    endpoint               = "mock.cluster-mock.eu-central-1.docdb.amazonaws.com"
    master_secret_arn      = "arn:aws:secretsmanager:eu-central-1:000000000000:secret:mock"
    read_secret_policy_arn = "arn:aws:iam::000000000000:policy/mock"
  }
}

inputs = {
  name   = "week3-${local.env.environment}"
  region = local.env.region

  # Скрипт лежит в каталоге Task 1 — один файл на обе задачи, копий нет.
  #
  # Путь строится от root.hcl, а не через get_repo_root(). Причина
  # практическая: Infracost при сканировании считает корнем репозитория тот
  # каталог, который ему передали, поэтому get_repo_root() возвращал
  # terragrunt/ и пути превращались в terragrunt/terragrunt/modules.
  # dirname(find_in_parent_folders("root.hcl")) привязан к самой конфигурации
  # и от внешнего инструмента не зависит.
  # АБСОЛЮТНЫЙ путь обязателен: templatefile() резолвит относительные пути
  # от рабочего каталога Terraform, то есть от .terragrunt-cache, а не от юнита.
  # get_terragrunt_dir() даёт настоящий каталог юнита; четыре уровня вверх —
  # это корень форка, где рядом с terragrunt/ лежит week3_task1/.
  user_data_path = "${get_terragrunt_dir()}/../../../../week3_task1/user_data/user_data.sh"

  instance_type      = local.env.instance_type
  security_group_ids = [dependency.sg.outputs.app_security_group_id]

  docdb_endpoint          = dependency.docdb.outputs.endpoint
  docdb_secret_arn        = dependency.docdb.outputs.master_secret_arn
  docdb_secret_policy_arn = dependency.docdb.outputs.read_secret_policy_arn
}
