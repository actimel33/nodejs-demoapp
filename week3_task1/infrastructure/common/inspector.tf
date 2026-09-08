# AWS Inspector v2 — непрерывная автоматическая оценка защищённости (Task 3*).
#
# Не путать с Inspector Classic: тот выведен из эксплуатации, у него были
# ресурсы aws_inspector_assessment_template и ручной запуск прогонов.
# Нынешний сервис включается один раз и работает постоянно, пересканируя
# ресурсы при появлении новых CVE.
#
# Это переключатель уровня АККАУНТА, а не объект: он включает сканирование
# для всего аккаунта целиком, включая инстансы, поднятые не этим Terraform.
#
# Чтобы сканирование EC2 работало, инстанс должен быть виден в Systems Manager:
# нужен агент SSM (в Amazon Linux 2023 предустановлен) и роль с политикой
# AmazonSSMManagedInstanceCore — она уже прицеплена в ec2.tf.
#

# Идентификатор текущего аккаунта: Inspector включается пер-аккаунт.
data "aws_caller_identity" "current" {}

resource "aws_inspector2_enabler" "main" {
  count = var.enable_inspector ? 1 : 0

  account_ids = [data.aws_caller_identity.current.account_id]

  # Допустимые значения: EC2, ECR, LAMBDA, LAMBDA_CODE, CODE_REPOSITORY.
  # ECR имеет смысл добавить, если собирать свой образ.
  resource_types = ["EC2"]
}
