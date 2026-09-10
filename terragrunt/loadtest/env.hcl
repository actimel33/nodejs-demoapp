# Параметры окружения loadtest — третье окружение из требования Task 2
# («add another environment catered for load testing»).
#
# ЭТО ВЕСЬ НОВЫЙ КОД, который понадобился для нового окружения. Юниты
# скопированы из dev как есть: каждый из них — четыре строки include,
# а всё содержательное живёт в _envcommon и вычисляется отсюда.
# Число строк укажи в README — это самый убедительный аргумент
# по критерию «minimize configuration duplication».

locals {
  environment = "loadtest"
  region      = "eu-central-1"

  vpc_cidr        = "10.50.0.0/16"
  public_subnets  = ["10.50.1.0/24", "10.50.2.0/24"]
  private_subnets = ["10.50.11.0/24", "10.50.12.0/24"]

  # Размеры ПОВТОРЯЮТ production — в этом весь смысл нагрузочного стенда.
  # Если тестировать на инстансе другого размера или на базе без реплики,
  # полученные числа не переносятся на production и тест бесполезен.
  instance_type        = "t3.small"
  asg_min_size         = 2
  asg_desired_capacity = 2
  cpu_target_value     = 40

  docdb_instance_class = "db.t4g.medium"
  docdb_instance_count = 2

  # ЕДИНСТВЕННОЕ осознанное отличие: потолок выше, чем в production (4).
  # Нужен запас, чтобы тест мог перешагнуть рабочий предел и показать,
  # где система ломается, а не упереться в тот же лимит.
  asg_max_size = 8
}
