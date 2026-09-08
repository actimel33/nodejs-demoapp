# Окружение production: два инстанса в разных зонах доступности и кластер базы
# с репликой.
# Применяется из каталога infrastructure/production:
#   terraform apply -var-file=../env/production.tfvars

environment = "production"

vpc_cidr             = "10.40.0.0/16"
public_subnet_cidrs  = ["10.40.1.0/24", "10.40.2.0/24"]
private_subnet_cidrs = ["10.40.11.0/24", "10.40.12.0/24"]

# Вдвое больше памяти, чем у t3.micro в dev: 2 ГиБ против 1.
instance_type = "t3.small"

# Минимум два инстанса в разных AZ: один — единая точка отказа,
# два переживают падение зоны. Потолок 4 — запас на пик нагрузки.
asg_min_size         = 2
asg_max_size         = 4
asg_desired_capacity = 2
cpu_target_value     = 40

# Бонусная часть: оповещения о событиях масштабирования.
# Адрес НЕ хранится в репозитории — форк публичный, а адреса с GitHub
# собирают боты. Передаётся в командной строке при применении:
#   terraform apply -var-file=../env/production.tfvars -var 'alert_email=твой@адрес'
enable_notifications = true
alert_email          = ""

# Два узла базы в разных зонах доступности: при отказе primary реплика
# становится primary автоматически, обычно за десятки секунд. Это главное
# отличие production от стенда — в dev одного узла достаточно.
enable_docdb         = false
docdb_instance_class = "db.t4g.medium"
docdb_instance_count = 2

enable_inspector = false
