# DocumentDB через СВОЙ модуль — это требование Task 2:
# «Write your own Terraform module for provisioning a specific resource,
#  say a virtual machine or a database instance».
#
# Почему именно DocumentDB: он состоит из нескольких ресурсов (subnet group,
# кластер, узлы), имеет понятную границу и всё равно нужен в Task 3.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  # Двойной слэш не опечатка: он отделяет корень источника
  # от пути к модулю внутри него.
  source = "../../../modules//docdb"
}

dependency "vpc" {
  config_path = "../../vpc"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    private_subnets = ["subnet-00000000", "subnet-11111111"]
  }
}

dependency "sg" {
  config_path = "../sg"

  mock_outputs_allowed_terraform_commands = ["validate", "plan"]
  mock_outputs = {
    docdb_security_group_id = "sg-00000000"
  }
}

inputs = {
  name       = "week3-${local.env.environment}"
  subnet_ids = dependency.vpc.outputs.private_subnets

  security_group_ids = [dependency.sg.outputs.docdb_security_group_id]

  instance_class = local.env.docdb_instance_class
  instance_count = local.env.docdb_instance_count
}
