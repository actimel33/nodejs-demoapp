# Общее описание юнита VPC для ВСЕХ окружений.
# В самих окружениях остаётся только include на четыре строки.

locals {
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env      = local.env_vars.locals
}

terraform {
  source = "tfr:///terraform-aws-modules/vpc/aws//?version=6.7.2"
}

inputs = {
  name = "week3-${local.env.environment}"
  cidr = local.env.vpc_cidr

  # Ровно две зоны: ALB требует минимум две подсети в разных AZ,
  # DocumentDB — тоже минимум две.
  azs             = ["${local.env.region}a", "${local.env.region}b"]
  public_subnets  = local.env.public_subnets
  private_subnets = local.env.private_subnets

  # NAT Gateway НЕ создаём: $0.052/час — дороже всей остальной инфраструктуры
  # недели. Инстансы приложения стоят в публичных подсетях и ходят наружу
  # через интернет-шлюз, а DocumentDB в приватных подсетях интернет не нужен.
  enable_nat_gateway = false

  # Без этого DocumentDB не резолвится по имени.
  enable_dns_hostnames = true
  enable_dns_support   = true

  map_public_ip_on_launch = true
}
