#!/usr/bin/env python3
import json
import os
import sys
import urllib.request
import urllib.error
import datetime

CONFIG_PATH = os.path.expanduser("~/.config/illogical-impulse/prayer_config.json")
CACHE_PATH = os.path.expanduser("~/.cache/prayer_data.json")

DEFAULT_CONFIG = {
    "city": "Гудермес",
    "latitude": 43.3506,
    "longitude": 46.0953,
    "method": 14,
    "hijri_offset": 1,
    "offsets": {
        "Fajr": 11,
        "Sunrise": -2,
        "Dhuhr": 51,
        "Asr": 22,
        "Maghrib": 5,
        "Isha": 14
    }
}

HIJRI_MONTHS = {
    1: "Мухаррам", 2: "Сафар", 3: "Раби аль-авваль", 4: "Раби ас-сани",
    5: "Джумада аль-уля", 6: "Джумада аль-ахира", 7: "Раджаб", 8: "Шаабан",
    9: "Рамадан", 10: "Шавваль", 11: "Зуль-Каада", 12: "Зуль-Хиджа"
}

def get_special_day(hijri_day, hijri_month):
    holidays = {
        (1, 1): "Новый год по Хиджре",
        (10, 1): "День Ашура",
        (12, 3): "Мавлид ан-Наби",
        (27, 7): "Исра и Мирадж",
        (15, 8): "Ночь Бараат",
        (1, 9): "Начало Рамадана",
        (27, 9): "Ляйлят уль-Кадр",
        (1, 10): "Ураза-Байрам",
        (2, 10): "Ураза-Байрам",
        (3, 10): "Ураза-Байрам",
        (9, 12): "День Арафа",
        (10, 12): "Курбан-Байрам",
        (11, 12): "Курбан-Байрам",
        (12, 12): "Курбан-Байрам",
        (13, 12): "Курбан-Байрам"
    }
    if (hijri_day, hijri_month) in holidays:
        return holidays[(hijri_day, hijri_month)]
    if hijri_month == 9:
        return "Рамадан"
    if datetime.date.today().weekday() == 4:
        return "Джума"
    return ""

def load_config():
    if os.path.exists(CONFIG_PATH):
        try:
            with open(CONFIG_PATH, "r", encoding="utf-8") as f:
                cfg = json.load(f)
                merged = DEFAULT_CONFIG.copy()
                merged.update(cfg)
                return merged
        except Exception as e:
            print(f"Config load error: {e}", file=sys.stderr)
    return DEFAULT_CONFIG

def adjust_time(time_str, delta_min):
    try:
        h, m = map(int, time_str.split(":")[:2])
        total_m = (h * 60 + m + delta_min) % (24 * 60)
        return f"{total_m // 60:02d}:{total_m % 60:02d}"
    except Exception:
        return time_str

def fetch_and_save():
    cfg = load_config()
    lat = cfg["latitude"]
    lon = cfg["longitude"]
    method = cfg.get("method", 14)
    offsets = cfg.get("offsets", {})
    hijri_offset = cfg.get("hijri_offset", 0)

    url = f"http://api.aladhan.com/v1/timings?latitude={lat}&longitude={lon}&method={method}"
    data = None
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode())["data"]
    except Exception as e:
        print(f"API fetch error: {e}, attempting cache...", file=sys.stderr)
        if os.path.exists(CACHE_PATH):
            try:
                with open(CACHE_PATH, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                pass

    if data:
        raw = data["timings"]
        hijri_num = int(data["date"]["hijri"]["month"]["number"])
        raw_hijri_day = int(data["date"]["hijri"]["day"])
        hijri_day = raw_hijri_day + hijri_offset
        hijri_str = f"{hijri_day} {HIJRI_MONTHS.get(hijri_num, '')}"
        special_day = get_special_day(hijri_day, hijri_num)

        fajr = adjust_time(raw.get("Fajr", "05:06"), offsets.get("Fajr", 0))
        sunrise = adjust_time(raw.get("Sunrise", "06:32"), offsets.get("Sunrise", 0))
        dhuhr = adjust_time(raw.get("Dhuhr", "11:39"), offsets.get("Dhuhr", 0))
        asr = adjust_time(raw.get("Asr", "14:23"), offsets.get("Asr", 0))
        maghrib = adjust_time(raw.get("Maghrib", "16:46"), offsets.get("Maghrib", 0))
        isha = adjust_time(raw.get("Isha", "18:06"), offsets.get("Isha", 0))

        result = {
            "title": "Время намаза",
            "hijri_date": hijri_str,
            "special_day": special_day,
            "fajr": fajr,
            "sunrise": sunrise,
            "dhuhr": dhuhr,
            "asr": asr,
            "maghrib": maghrib,
            "isha": isha,
            "updated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        try:
            with open(CACHE_PATH, "w", encoding="utf-8") as f:
                json.dump(result, f, ensure_ascii=False, indent=2)
        except Exception as e:
            print(f"Cache write error: {e}", file=sys.stderr)
        return result
    else:
        return {
            "title": "Время намаза",
            "hijri_date": "23 Джумада аль-уля",
            "special_day": "",
            "fajr": "05:17",
            "sunrise": "06:30",
            "dhuhr": "12:30",
            "asr": "14:45",
            "maghrib": "16:51",
            "isha": "18:20",
            "updated_at": "offline-defaults"
        }

if __name__ == "__main__":
    res = fetch_and_save()
    print(json.dumps(res, ensure_ascii=False))
