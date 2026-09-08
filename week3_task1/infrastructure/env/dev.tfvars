# Окружение разработки: минимум ресурсов, минимум денег.
# Применяется из каталога infrastructure/dev:
#   terraform apply -var-file=../env/dev.tfvars

environment = "dev"

# CIDR не пересекается с production и loadtest.
# Это не формальность: пересечение сделает невозможным пиринг между
# окружениями, если он когда-нибудь понадобится.
vpc_cidr             = "10.30.0.0/16"
public_subnet_cidrs  = ["10.30.1.0/24", "10.30.2.0/24"]
private_subnet_cidrs = ["10.30.11.0/24", "10.30.12.0/24"]

instance_type        = "t3.micro"
asg_min_size         = 1
asg_max_size         = 2
asg_desired_capacity = 1
cpu_target_value     = 40

# Бонусная часть. Свой адрес и подтверди подписку по ссылке из письма.
enable_notifications = false
alert_email          = ""

# Task 3.
enable_docdb         = false
docdb_instance_class = "db.t4g.medium"
docdb_instance_count = 1

enable_inspector = false
