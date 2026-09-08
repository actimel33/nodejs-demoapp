# Сеть. Написана явными ресурсами, а не модулем terraform-aws-modules/vpc,
# по одной причине: так гарантированно нет NAT Gateway.
# инстансы приложения стоят в публичных подсетях и ходят в интернет через
# интернет-шлюз, а DocumentDB в приватных подсетях в интернете не нуждается.

# Зоны доступности берём из API, а не строкой "eu-central-1a":
# конфигурация останется рабочей в любом регионе.
data "aws_availability_zones" "available" {
  state = "available"
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true # без этого DocumentDB не резолвится по имени

  tags = { Name = "${local.name_prefix}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-igw" }
}

# ---------------------------------------------------------------------------
# Публичные подсети: ALB и инстансы приложения
# ---------------------------------------------------------------------------

resource "aws_subnet" "public" {
  # for_each по индексам, а не count: удаление подсети из списка не сдвинет
  # адреса остальных и не заставит Terraform их пересоздавать.
  for_each = { for idx, cidr in var.public_subnet_cidrs : idx => cidr }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = {
    Name = "${local.name_prefix}-public-${local.azs[tonumber(each.key)]}"
    Tier = "public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }

  tags = { Name = "${local.name_prefix}-public-rt" }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# ---------------------------------------------------------------------------
# Приватные подсети: DocumentDB
# ---------------------------------------------------------------------------

resource "aws_subnet" "private" {
  for_each = { for idx, cidr in var.private_subnet_cidrs : idx => cidr }

  vpc_id            = aws_vpc.main.id
  cidr_block        = each.value
  availability_zone = local.azs[tonumber(each.key)]

  tags = {
    Name = "${local.name_prefix}-private-${local.azs[tonumber(each.key)]}"
    Tier = "private"
  }
}

# Таблица маршрутизации без единого маршрута наружу. «приватность»:
# трафик внутри VPC ходит по локальному маршруту, которого в таблице не видно —
# он есть всегда и неявно.
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  tags = { Name = "${local.name_prefix}-private-rt" }
}

resource "aws_route_table_association" "private" {
  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
