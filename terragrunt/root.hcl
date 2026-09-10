# Корневая конфигурация Terragrunt: подключается КАЖДЫМ юнитом.
#
# Называется root.hcl, а не terragrunt.hcl, намеренно. Раньше рекомендовали
# корневой terragrunt.hcl, но Terragrunt не мог отличить его от юнита и
# пытался применить корень как инфраструктуру. С переходом на 1.x
# рекомендуемое имя — root.hcl, а find_in_parent_folders() вызывается
# с ЯВНЫМ именем файла.
#
# Схема в документе задания показывает старую структуру. Делаем современную —
# и объясняем причину в README.

locals {
  # Параметры окружения лежат в env.hcl рядом с каталогом окружения.
  # Так любой юнит знает, в каком он окружении, не получая это параметром.
  env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  environment = local.env_vars.locals.environment
  region      = local.env_vars.locals.region
  project     = "week3"

  name_prefix = "${local.project}-${local.environment}"
}

# ---------------------------------------------------------------------------
# Состояние
# ---------------------------------------------------------------------------
#
# ГЛАВНАЯ строка всего файла — key. path_relative_to_include() даёт каждому
# юниту СВОЙ ключ в S3, вычисленный из пути: dev/vpc, dev/app/alb,
# production/vpc окажутся в разных файлах состояния БЕЗ единой строки
# настройки в самих юнитах. Ради этого Terragrunt и берут.
#
# ЗАМЕНИТЬ имя бакета на своё.

remote_state {
  backend = "s3"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    bucket = "itsyndicate-tfstate-andrew"
    key    = "terragrunt/${path_relative_to_include()}/terraform.tfstate"
    region = local.region

    encrypt = true

    # Блокировка через сам S3 — с Terraform 1.10 отдельная таблица DynamoDB
    # не нужна, а dynamodb_table помечен устаревшим.
    use_lockfile = true
  }
}

# ---------------------------------------------------------------------------
# Оценка стоимости рядом с планом
# ---------------------------------------------------------------------------
#
# Требование задания сформулировано точно: «running a plan for any environment
# produces a cost estimate ALONGSIDE the Terraform plan». То есть цифра должна
# появляться вместе с планом, а не отдельной командой, которую надо помнить.
#
# Хук навешан на команду plan и срабатывает в любом юните любого окружения,
# включая loadtest.
#
# Три решения, которые стоит понимать:
#
# 1. Сканируется КАТАЛОГ ЮНИТА, а не рабочая директория Terraform.
#    Хук выполняется в .terragrunt-cache, куда Terragrunt скачал модуль,
#    и там нет входов из inputs — оценка вышла бы по умолчаниям модуля.
#    get_terragrunt_dir() указывает на настоящий каталог юнита, где лежит
#    terragrunt.hcl, и Infracost сам определяет проект как Terragrunt.
#
# 2. Отсутствие infracost НЕ ЛОМАЕТ план. Хук, завершившийся с ошибкой,
#    роняет всю команду — поэтому наличие бинарника проверяется заранее,
#    а хвост `|| true` глушит и неудачу самого сканирования, например
#    когда не пройдена авторизация.
#
# 3. Оценку можно выключить: TG_SKIP_INFRACOST=1 terragrunt plan.
#    Сканирование добавляет к плану десятки секунд, и при отладке
#    конфигурации это лишнее.
#
# 4. Подкоманда выбирается по версии. У Infracost две живые мажорные ветки
#    с несовместимым CLI: в 0.10.x оценку считает `breakdown --path`,
#    в 2.x её переименовали в `scan`. Скрипт установки из репозитория
#    infracost/infracost ставит 0.10.x, из infracost/cli — 2.x, поэтому
#    угадывать нельзя: хук определяет доступную команду сам.
#
# 5. НА ЭТОМ ПРОЕКТЕ НУЖНА ВЕТКА 0.10.x. В версии 2.x появилась проверка
#    путей, которая отвергает include за пределами каталога юнита:
#      Security problem: include path .../_envcommon/alb.hcl
#      is not within an allowed directory
#    Под неё попадает _envcommon — тот самый паттерн, который Gruntwork
#    рекомендует для устранения дублирования. Результат: 2.x разбирает
#    только часть юнитов и выдаёт неполную оценку, 0.10.x — все семь.
#    Флага, ослабляющего проверку, в 2.x нет.
#
#    Два рекомендованных инструмента, чьи соглашения столкнулись.
#    Выбрана работающая комбинация, а не свежая версия ради свежести.

terraform {
  after_hook "infracost" {
    commands = ["plan"]

    execute = ["sh", "-c", <<-CMD
      UNIT="${get_terragrunt_dir()}"
      export INFRACOST_SKIP_UPDATE_CHECK=true
      if [ -n "$TG_SKIP_INFRACOST" ]; then
        echo "── infracost пропущен (TG_SKIP_INFRACOST задан)"
      elif ! command -v infracost >/dev/null 2>&1; then
        echo "── infracost не установлен, оценка стоимости пропущена"
      else
        echo "── оценка стоимости: ${path_relative_to_include()}"
        if infracost --help 2>&1 | grep -qE '^\s+scan\s'; then
          infracost scan "$UNIT" --no-color || true
        else
          infracost breakdown --path "$UNIT" --no-color || true
        fi
      fi
    CMD
    ]
  }
}

# ---------------------------------------------------------------------------
# Провайдер
# ---------------------------------------------------------------------------
#
# Генерируется в каждый юнит. Без Terragrunt этот блок пришлось бы копировать
# в каждый из десятка каталогов вручную.

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"

  contents = <<-EOT
    provider "aws" {
      region = "${local.region}"

      default_tags {
        tags = {
          Project     = "${local.project}"
          Environment = "${local.environment}"
          ManagedBy   = "terragrunt"
          Owner       = "andrew"
        }
      }
    }
  EOT
}

# Общих входов здесь НЕТ намеренно.
#
# Соблазн положить сюда что-нибудь вроде name_prefix или environment велик:
# кажется, что это удобно — «пусть будет доступно везде». Но Terragrunt
# передаёт входы из root.hcl КАЖДОМУ юниту, включая те, что вызывают чужие
# модули из реестра. Если у такого модуля окажется переменная с тем же именем,
# он получит её молча и поведёт себя неожиданно.
#
# Именно так и вышло: name_prefix из root попадал в terraform-aws-modules/alb,
# у которого есть своя переменная name_prefix, взаимоисключающая с name.
# Ошибка вылезала только на plan:
#   "name": conflicts with name_prefix
#
# Поэтому каждый юнит передаёт ровно то, что нужно его модулю, — в _envcommon.
# Здесь остаются только backend и provider, то есть вещи, которые действительно
# общие для всех и ни с чем не конфликтуют.
