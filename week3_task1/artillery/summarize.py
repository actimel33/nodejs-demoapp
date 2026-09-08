#!/usr/bin/env python3
"""Сводка по отчёту Artillery в читаемом виде.

Зачем: команда `artillery report`, которая раньше собирала HTML, в Artillery 2.x
УПРАЗДНЕНА — вместо неё предлагают облачный сервис Artillery Cloud с регистрацией.
Все нужные числа лежат в report.json, который пишет `artillery run --output`,
поэтому проще собрать сводку самому.

Запуск:
    python3 artillery/summarize.py report.json
"""
import json
import sys


def ms(v):
    return "—" if v is None else f"{v:.0f} мс"


def main(path):
    agg = json.load(open(path))["aggregate"]
    c = agg.get("counters", {})
    r = agg.get("rates", {})
    s = agg.get("summaries", {})

    dur = (agg["lastCounterAt"] - agg["firstCounterAt"]) / 1000

    print("=" * 62)
    print("НАГРУЗОЧНЫЙ ТЕСТ — СВОДКА")
    print("=" * 62)
    print(f"Длительность              {dur / 60:.1f} мин")
    print(f"Виртуальных пользователей {c.get('vusers.created', 0)}")
    print(f"  завершено               {c.get('vusers.completed', 0)}")
    print(f"  прервано                {c.get('vusers.failed', 0)}")
    print(f"HTTP-запросов             {c.get('http.requests', 0)}")
    print(f"Средний RPS               {r.get('http.request_rate', 0):.1f}")
    print(f"Скачано                   {c.get('http.downloaded_bytes', 0) / 1024 / 1024:.0f} МБ")

    print("\nКоды ответов")
    for k in sorted(k for k in c if k.startswith("http.codes.")):
        code = k.rsplit(".", 1)[1]
        total = c.get("http.responses", 1)
        print(f"  {code}   {c[k]:>7}   {c[k] / total * 100:5.2f}%")
    err = c.get("errors.ETIMEDOUT", 0) + c.get("errors.ECONNRESET", 0)
    if err:
        print(f"  ошибок соединения {err}")

    rt = s.get("http.response_time", {})
    print("\nВремя ответа (все запросы)")
    for label, key in [("минимум", "min"), ("медиана", "median"),
                       ("p95", "p95"), ("p99", "p99"), ("максимум", "max")]:
        print(f"  {label:<10} {ms(rt.get(key))}")

    print("\nВремя ответа по эндпоинтам")
    prefix = "plugins.metrics-by-endpoint.response_time."
    for k in sorted(k for k in s if k.startswith(prefix)):
        ep = k[len(prefix):]
        d = s[k]
        print(f"  {ep:<14} медиана {ms(d.get('median')):>9}   p95 {ms(d.get('p95')):>9}   макс {ms(d.get('max')):>9}")

    print("=" * 62)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "report.json")
