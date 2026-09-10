# Модуль `docdb`

Кластер Amazon DocumentDB как одна сущность: подсети, кластер, узлы и IAM-политика на чтение пароля.

## Что создаёт

| Ресурс | Зачем |
|---|---|
| `aws_docdb_subnet_group` | подсети кластера, минимум две AZ — требование сервиса |
| `aws_docdb_cluster` | сам кластер: хранилище, эндпоинты, бэкапы |
| `aws_docdb_cluster_instance` | вычислительные узлы, `instance_count` штук |
| `aws_iam_policy` | право читать секрет с паролем — прицепляется к роли инстансов |

## Входы

| Имя | Тип | По умолчанию | Описание |
|---|---|---|---|
| `name` | `string` | — | базовое имя, например `week3-dev` |
| `subnet_ids` | `list(string)` | — | приватные подсети, минимум две в разных AZ |
| `security_group_ids` | `list(string)` | — | группы, которые вешаются на кластер |
| `master_username` | `string` | `appuser` | имя главного пользователя |
| `instance_class` | `string` | `db.t4g.medium` | класс узла, самый дешёвый поддерживаемый |
| `instance_count` | `number` | `1` | число узлов, 1-3 |
| `backup_retention_period` | `number` | `1` | дней хранения бэкапов |
| `deletion_protection` | `bool` | `false` | защита от удаления |
| `skip_final_snapshot` | `bool` | `true` | не делать снапшот при удалении |
| `create_secret_read_policy` | `bool` | `true` | создавать ли IAM-политику на чтение секрета |
| `tags` | `map(string)` | `{}` | дополнительные теги |

## Выходы

| Имя | Описание |
|---|---|
| `cluster_identifier` | идентификатор кластера |
| `endpoint` | адрес записи — всегда указывает на текущий primary |
| `reader_endpoint` | адрес чтения, балансирует по репликам |
| `port` | порт, по умолчанию 27017 |
| `master_secret_arn` | ARN секрета с логином и паролем в Secrets Manager |
| `read_secret_policy_arn` | ARN политики на чтение секрета |

## Пример

```hcl
module "docdb" {
  source = "../../modules/docdb"

  name               = "week3-dev"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [module.security.docdb_security_group_id]

  instance_class = "db.t4g.medium"
  instance_count = 1
}
```

## Три решения, которые стоит понимать

**Пароль не задаётся вручную.** Модуль ставит `manage_master_user_password = true`: пароль генерирует и хранит AWS в Secrets Manager. Причина в предупреждении из документации провайдера — **все аргументы, включая `master_password`, сохраняются в state открытым текстом**. Вариант с паролем в переменной означает пароль в state, а часто и в `tfvars` рядом с кодом. Здесь наружу отдаётся только ARN секрета, а инстанс читает его сам по своей IAM-роли.

**IAM не аутентифицирует DocumentDB.** У сервиса нет действия `docdb:Connect` — в отличие от RDS с `rds-db:connect` или DynamoDB. Никакая политика не пустит и не остановит запрос к порту 27017: это работа security group. Политика из этого модуля контролирует доступ к **паролю**, а не к базе, и `Resource` в ней — конкретный ARN, а не `"*"`.

**Умолчания рассчитаны на стенд, окружения их переопределяют.** `deletion_protection = false` и `skip_final_snapshot = true` — чтобы `destroy` проходил и не оставлял забытый кластер за $2.1 в сутки; в настоящем production оба значения были бы противоположными. А вот `instance_count` окружения задают сами: `1` в `dev`, `2` в `production` и `loadtest` — два узла в разных зонах дают автоматическое переключение при отказе primary.

## Стоимость

eu-central-1, по прайс-листу AWS: `db.t4g.medium` — **$0.08924/час**, хранилище $0.119 за ГБ в месяц, операции ввода-вывода $0.22 за миллион. Один узел — самая дорогая позиция недели.
