# Параметры окружения dev. ЕДИНСТВЕННЫЙ файл, который отличает окружения
# друг от друга — в этом и проверяется, насколько структура DRY.

locals {
  environment = "dev"
  region      = "eu-central-1"

  # CIDR не пересекается с production (10.40) и loadtest (10.50)
  vpc_cidr        = "10.30.0.0/16"
  public_subnets  = ["10.30.1.0/24", "10.30.2.0/24"]
  private_subnets = ["10.30.11.0/24", "10.30.12.0/24"]

  instance_type        = "t3.micro"
  asg_min_size         = 1
  asg_max_size         = 2
  asg_desired_capacity = 1
  cpu_target_value     = 40

  docdb_instance_class = "db.t4g.medium"
  docdb_instance_count = 1
}
