# Параметры окружения production. ЕДИНСТВЕННЫЙ файл, который отличает окружения
# друг от друга — в этом и проверяется, насколько структура DRY.

locals {
  environment = "production"
  region      = "eu-central-1"

  # CIDR не пересекается с dev (10.30) и loadtest (10.50)
  vpc_cidr        = "10.40.0.0/16"
  public_subnets  = ["10.40.1.0/24", "10.40.2.0/24"]
  private_subnets = ["10.40.11.0/24", "10.40.12.0/24"]

  # Вдвое больше памяти, чем t3.micro в dev. $0.024/час против $0.012.
  # НЕ t3.medium: аккаунт в режиме AWS Free Plan не даёт запускать типы
  # вне free tier — ASG падает с "not eligible for Free Tier".
  instance_type        = "t3.small"
  asg_min_size         = 2
  asg_max_size         = 4
  asg_desired_capacity = 2
  cpu_target_value     = 40

  docdb_instance_class = "db.t4g.medium"
  # Два узла в разных AZ: при отказе primary реплика становится primary
  # автоматически. Это и есть высокая доступность, ради которой всё затевалось.
  docdb_instance_count = 2
}
