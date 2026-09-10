# Юнит = один вызов модуля = ОДИН state.
# Всё содержательное живёт в _envcommon/cloudwatch.hcl и вычисляется из env.hcl.
# Здесь остаётся только подключение — в этом и есть DRY.

include "root" {
  path = find_in_parent_folders("root.hcl")
}

include "envcommon" {
  path           = "../../../_envcommon/cloudwatch.hcl"
  merge_strategy = "deep"
}
