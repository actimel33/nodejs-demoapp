#!/bin/bash
#
# User data для launch template группы автомасштабирования.
#
# Выполняется cloud-init от root ТОЛЬКО при первом старте инстанса.
# Логи: /var/log/cloud-init-output.log
#
# Файл является шаблоном terraform templatefile(): переменные $${...} подставляет
# Terraform, а bash-переменные экранированы двойным долларом ($${VAR}),
# иначе Terraform попытается развернуть их сам и упадёт на "unknown variable".
#
# Ожидаемые переменные шаблона:
#   environment     — dev | production, попадает в переменные окружения приложения
#   docdb_endpoint  — адрес кластера DocumentDB ("" если базы нет)
#   docdb_secret_id — ARN секрета с логином и паролем ("" если базы нет)
#   aws_region      — регион для AWS CLI
#
set -euo pipefail

# Метки этапов: по ним в cloud-init-output.log видно, до какого места дошло.
log() { echo "### [user-data] $*"; }

log "install docker"
dnf install -y docker
systemctl enable --now docker

# --------------------------------------------------------------------------
# Базовый набор переменных окружения приложения
# --------------------------------------------------------------------------
DOCKER_ENV_ARGS=(-e "NODE_ENV=${environment}")
DOCKER_MOUNT_ARGS=()

# --------------------------------------------------------------------------
# Подключение к DocumentDB. Если endpoint пустой — блок пропускается,
# и приложение работает без раздела /todo.
# --------------------------------------------------------------------------
if [ -n "${docdb_endpoint}" ]; then
  log "configure DocumentDB connection"

  # Корневые сертификаты Amazon RDS: DocumentDB требует TLS, без бандла
  # драйвер MongoDB не подключится.
  mkdir -p /opt/rds
  curl -sSfo /opt/rds/global-bundle.pem \
    https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem

  # Пароль забираем из Secrets Manager по IAM-роли инстанса.
  # В user data его быть не должно: user data видна всем, у кого есть доступ
  # к инстансу, и хранится открытым текстом в описании launch template.
  # В Amazon Linux 2023 AWS CLI v2 предустановлен; ставим только если его нет.
  command -v aws >/dev/null 2>&1 || dnf install -y awscli-2

  SECRET_JSON=$(aws secretsmanager get-secret-value \
    --region "${aws_region}" \
    --secret-id "${docdb_secret_id}" \
    --query SecretString --output text)

  # Логин и пароль ПРОЦЕНТНО-КОДИРУЕМ перед подстановкой в URI.
  #
  # AWS генерирует пароль из случайных символов, и среди них попадаются такие,
  # которые в URI имеют своё значение: # начинает якорь, @ отделяет
  # учётные данные от хоста, / и ? — путь и параметры. Без кодирования драйвер
  # MongoDB падает с "MongoParseError: Password contains unescaped characters",
  # причём приложение при этом стартует и отдаёт страницы — не работает только
  # раздел /todo, а /api/todo возвращает 500.
  #
  # safe="" в quote() обязателен: без него / остаётся незакодированным.
  DOCDB_USER=$(echo "$${SECRET_JSON}" | python3 -c 'import sys,json,urllib.parse;print(urllib.parse.quote(json.load(sys.stdin)["username"], safe=""))')
  DOCDB_PASS=$(echo "$${SECRET_JSON}" | python3 -c 'import sys,json,urllib.parse;print(urllib.parse.quote(json.load(sys.stdin)["password"], safe=""))')

  # retryWrites=false обязателен: DocumentDB не поддерживает retryable writes,
  # а драйвер MongoDB включает их по умолчанию.
  CONNSTR="mongodb://$${DOCDB_USER}:$${DOCDB_PASS}@${docdb_endpoint}:27017/?tls=true&tlsCAFile=/certs/global-bundle.pem&replicaSet=rs0&readPreference=secondaryPreferred&retryWrites=false"

  DOCKER_ENV_ARGS+=(-e "TODO_MONGO_CONNSTR=$${CONNSTR}" -e "TODO_MONGO_DB=todoDb")
  DOCKER_MOUNT_ARGS+=(-v /opt/rds/global-bundle.pem:/certs/global-bundle.pem:ro)
fi

# --------------------------------------------------------------------------
# Запуск приложения. Снаружи 80, внутри контейнера 3000.
# --------------------------------------------------------------------------
log "run demoapp container"
docker run -d \
  --name demoapp \
  --restart always \
  -p 80:3000 \
  "$${DOCKER_ENV_ARGS[@]}" \
  "$${DOCKER_MOUNT_ARGS[@]}" \
  ghcr.io/benc-uk/nodejs-demoapp:latest

log "done"
