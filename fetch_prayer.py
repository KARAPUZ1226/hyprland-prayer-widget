#!/usr/bin/env python3
"""
Hyprland Prayer Times Service (Backend)
Robust prayer time fetching with offline astronomical calculation fallback,
Hijri calendar calculation, and Material You context metadata.
"""

import argparse
import datetime
import json
import math
import os
import sys
import urllib.error
import urllib.request

DEFAULT_CONFIG_PATHS = [
    os.path.expanduser("~/.config/illogical-impulse/prayer_config.json"),
    os.path.join(os.path.dirname(os.path.abspath(__file__)), "config.json"),
    os.path.expanduser("~/.config/quickshell/prayer-widget/config.json"),
]
CACHE_PATH = os.path.expanduser("~/.cache/prayer_data.json")

DEFAULT_CONFIG = {
    "city": "Гудермес",
    "latitude": 43.3506,
    "longitude": 46.0953,
    "method": 14,
    "school": 0,
    "hijri_offset": 1,
    "offsets": {
        "Fajr": 11,
        "Sunrise": -2,
        "Dhuhr": 51,
        "Asr": 22,
        "Maghrib": 5,
        "Isha": 14,
    },
    "position": {"top": 80, "left": 40},
    "layer": "bottom",
    "theme": "auto",
}

HIJRI_MONTHS = {
    1: "Мухаррам",
    2: "Сафар",
    3: "Раби аль-авваль",
    4: "Раби ас-сани",
    5: "Джумада аль-уля",
    6: "Джумада аль-ахира",
    7: "Раджаб",
    8: "Шаабан",
    9: "Рамадан",
    10: "Шавваль",
    11: "Зуль-Каада",
    12: "Зуль-Хиджа",
}

METHOD_ANGLES = {
    1: (18.0, 18.0),   # Karachi
    2: (15.0, 15.0),   # ISNA
    3: (18.0, 17.0),   # MWL
    4: (18.5, 90.0),   # Makkah (+90 min after Maghrib)
    5: (19.5, 17.5),   # Egypt
    13: (18.0, 17.0),  # Diyanet
    14: (16.0, 15.0),  # Russia SAMR
}


def get_special_day(hijri_day, hijri_month):
    """Detect special days and Islamic celebrations."""
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
        (13, 12): "Курбан-Байрам",
    }
    if (hijri_day, hijri_month) in holidays:
        return holidays[(hijri_day, hijri_month)]
    if hijri_month == 9:
        return "Рамадан"
    if datetime.date.today().weekday() == 4:
        return "Джума"
    return ""


def gregorian_to_hijri(date, offset=0):
    """Deterministic astronomical algorithm for Gregorian -> Hijri date."""
    y, m, d = date.year, date.month, date.day
    if m < 3:
        y -= 1
        m += 12
    a = y // 100
    b = 2 - a + a // 4
    jd = int(365.25 * (y + 4716)) + int(30.6001 * (m + 1)) + d + b - 1524

    epoch = 1948440
    l = jd - epoch + 10632
    n = (l - 1) // 10631
    l = l - 10631 * n + 354
    j = ((10985 - l) // 5316) * ((50 * l) // 17719) + (l // 5670) * ((43 * l) // 15238)
    l = l - ((30 - j) // 15) * ((17719 * j) // 50) - (j // 16) * ((15238 * j) // 43) + 29
    m_h = (24 * l) // 709
    d_h = l - (709 * m_h) // 24
    y_h = 30 * n + j - 30

    d_h += offset
    if d_h > 30:
        d_h -= 30
        m_h += 1
        if m_h > 12:
            m_h = 1
            y_h += 1
    elif d_h < 1:
        d_h += 30
        m_h -= 1
        if m_h < 1:
            m_h = 12
            y_h -= 1

    return y_h, m_h, d_h


def calculate_solar_timings(lat, lon, tz_offset, date=None, method=14, school=0, offsets=None):
    """
    Pure Python astronomical solar prayer calculation (Jean Meeus algorithm).
    Supports all standard conventions with zero external dependencies.
    """
    if date is None:
        date = datetime.date.today()
    if offsets is None:
        offsets = {}

    fajr_angle, isha_angle = METHOD_ANGLES.get(method, (16.0, 15.0))
    asr_factor = 2 if school == 1 else 1

    y, m, d = date.year, date.month, date.day
    d_j2000 = 367 * y - (7 * (y + (m + 9) // 12)) // 4 + (275 * m) // 9 + d - 730531.5

    m_anom = (357.529 + 0.98560028 * d_j2000) % 360
    l_sun = (280.459 + 0.98564736 * d_j2000) % 360
    lambda_sun = (
        l_sun
        + 1.915 * math.sin(math.radians(m_anom))
        + 0.020 * math.sin(math.radians(2 * m_anom))
    ) % 360

    obliquity = 23.439 - 0.00000036 * d_j2000
    alpha = math.degrees(
        math.atan2(
            math.cos(math.radians(obliquity)) * math.sin(math.radians(lambda_sun)),
            math.cos(math.radians(lambda_sun)),
        )
    )
    delta = math.degrees(
        math.asin(
            math.sin(math.radians(obliquity)) * math.sin(math.radians(lambda_sun))
        )
    )

    ra_hours = alpha / 15.0
    l_hours = l_sun / 15.0
    diff = l_hours - ra_hours
    while diff > 12:
        diff -= 24
    while diff < -12:
        diff += 24
    eq_t = diff

    noon = 12.0 + tz_offset - (lon / 15.0) - eq_t

    def hour_angle(alt_deg):
        val = (
            math.sin(math.radians(alt_deg))
            - math.sin(math.radians(lat)) * math.sin(math.radians(delta))
        ) / (math.cos(math.radians(lat)) * math.cos(math.radians(delta)))
        if val > 1.0 or val < -1.0:
            return None
        return math.degrees(math.acos(val)) / 15.0

    ha_sun = hour_angle(-0.833)
    sunrise = noon - ha_sun if ha_sun else noon - 6.0
    sunset = noon + ha_sun if ha_sun else noon + 6.0

    ha_fajr = hour_angle(-fajr_angle)
    fajr = noon - ha_fajr if ha_fajr else sunrise - 1.5

    if method == 4:
        isha = sunset + 1.5
    else:
        ha_isha = hour_angle(-isha_angle)
        isha = noon + ha_isha if ha_isha else sunset + 1.5

    phi_diff = abs(lat - delta)
    asr_alt = math.degrees(math.atan(1.0 / (asr_factor + math.tan(math.radians(phi_diff)))))
    ha_asr = hour_angle(asr_alt)
    asr = noon + ha_asr if ha_asr else noon + 3.0

    def to_min(h):
        h = (h + 24) % 24
        return int(round(h * 60))

    fajr_m = (to_min(fajr) + offsets.get("Fajr", 0)) % 1440
    sunrise_m = (to_min(sunrise) + offsets.get("Sunrise", 0)) % 1440
    dhuhr_m = (to_min(noon) + offsets.get("Dhuhr", 0)) % 1440
    asr_m = (to_min(asr) + offsets.get("Asr", 0)) % 1440
    maghrib_m = (to_min(sunset) + offsets.get("Maghrib", 0)) % 1440
    isha_m = (to_min(isha) + offsets.get("Isha", 0)) % 1440

    # Islamic Midnight & Tahajjud (last third of night)
    night_len = (fajr_m + 1440 - maghrib_m) % 1440
    midnight_m = (maghrib_m + night_len // 2) % 1440
    tahajjud_m = (maghrib_m + (2 * night_len) // 3) % 1440

    def fmt(m):
        return f"{m // 60:02d}:{m % 60:02d}"

    return {
        "fajr": fmt(fajr_m),
        "sunrise": fmt(sunrise_m),
        "dhuhr": fmt(dhuhr_m),
        "asr": fmt(asr_m),
        "maghrib": fmt(maghrib_m),
        "isha": fmt(isha_m),
        "midnight": fmt(midnight_m),
        "tahajjud": fmt(tahajjud_m),
    }


def load_config(custom_path=None):
    """Load configuration from specified or standard paths."""
    merged = DEFAULT_CONFIG.copy()
    paths = [custom_path] if custom_path else DEFAULT_CONFIG_PATHS
    for p in paths:
        if p and os.path.exists(p):
            try:
                with open(p, "r", encoding="utf-8") as f:
                    cfg = json.load(f)
                    merged.update(cfg)
                    return merged
            except Exception as e:
                print(f"Config load error from {p}: {e}", file=sys.stderr)
    return merged


def adjust_time(time_str, delta_min):
    """Adjust a HH:MM time string by delta_min minutes."""
    try:
        h, m = map(int, time_str.split(":")[:2])
        total_m = (h * 60 + m + delta_min) % (24 * 60)
        return f"{total_m // 60:02d}:{total_m % 60:02d}"
    except Exception:
        return time_str


def parse_min(s):
    """Parse HH:MM string to total minutes from midnight."""
    if not s:
        return 0
    parts = s.split(":")
    return int(parts[0]) * 60 + int(parts[1])


def compute_schedule_state(timings, now=None):
    """
    Calculate current prayer, next prayer, remaining time,
    progress between prayers, and daylight/night phase.
    """
    if now is None:
        now = datetime.datetime.now()
    cur_m = now.hour * 60 + now.minute
    cur_s = cur_m * 60 + now.second

    schedule = [
        {"key": "fajr", "name": "Фаджр", "time": timings["fajr"], "type": "dawn"},
        {"key": "sunrise", "name": "Восход", "time": timings["sunrise"], "type": "sunrise"},
        {"key": "dhuhr", "name": "Зухр", "time": timings["dhuhr"], "type": "day"},
        {"key": "asr", "name": "Аср", "time": timings["asr"], "type": "day"},
        {"key": "maghrib", "name": "Магриб", "time": timings["maghrib"], "type": "sunset"},
        {"key": "isha", "name": "Иша", "time": timings["isha"], "type": "night"},
    ]

    for item in schedule:
        item["minutes"] = parse_min(item["time"])

    # Determine next prayer and interval
    next_idx = None
    for i, item in enumerate(schedule):
        if item["minutes"] > cur_m:
            next_idx = i
            break

    if next_idx is not None:
        next_item = schedule[next_idx]
        prev_item = schedule[next_idx - 1] if next_idx > 0 else schedule[-1]
        diff_min = next_item["minutes"] - cur_m

        if next_idx == 0:
            # Between midnight and Fajr
            interval_len = (next_item["minutes"] + 1440 - prev_item["minutes"]) % 1440
            elapsed = (cur_m + 1440 - prev_item["minutes"]) % 1440
        else:
            interval_len = next_item["minutes"] - prev_item["minutes"]
            elapsed = cur_m - prev_item["minutes"]
    else:
        # After Isha, waiting for tomorrow's Fajr
        next_item = schedule[0]
        prev_item = schedule[-1]
        diff_min = (1440 - cur_m) + next_item["minutes"]
        interval_len = (next_item["minutes"] + 1440 - prev_item["minutes"]) % 1440
        elapsed = cur_m - prev_item["minutes"]

    progress = max(0.0, min(1.0, elapsed / interval_len)) if interval_len > 0 else 0.0

    rem_h = diff_min // 60
    rem_m = diff_min % 60
    rem_str = f"{rem_h:02d}:{rem_m:02d}"
    rem_human = f"{rem_h} ч {rem_m} мин" if rem_h > 0 else f"{rem_m} мин"

    next_parts = next_item["time"].split(":")
    hours_str = next_parts[0] if len(next_parts) > 0 else "00"
    mins_str = next_parts[1] if len(next_parts) > 1 else "00"

    return {
        "current_prayer": {
            "key": prev_item["key"],
            "name": prev_item["name"],
            "time": prev_item["time"],
        },
        "next_prayer": {
            "key": next_item["key"],
            "name": next_item["name"],
            "time": next_item["time"],
            "hours": hours_str,
            "minutes": mins_str,
            "diff_minutes": diff_min,
            "remaining_str": rem_str,
            "remaining_human": rem_human,
            "type": next_item["type"],
        },
        "progress": round(progress, 3),
        "time_type": next_item["type"],
    }


def fetch_prayer_times(config_path=None, force_offline=False):
    """
    Multi-tier resilient prayer time retriever:
    1. Online Aladhan HTTPS API
    2. Local daily cache
    3. Pure Python offline astronomical calculation
    """
    cfg = load_config(config_path)
    lat = cfg["latitude"]
    lon = cfg["longitude"]
    method = cfg.get("method", 14)
    school = cfg.get("school", 0)
    offsets = cfg.get("offsets", {})
    hijri_offset = cfg.get("hijri_offset", 1)
    city = cfg.get("city", "Гудермес")

    tz_sec = datetime.datetime.now().astimezone().utcoffset().total_seconds()
    tz_offset = tz_sec / 3600.0

    today = datetime.date.today()
    date_str = today.strftime("%d-%m-%Y")
    data = None
    source = "offline_calc"

    if not force_offline:
        url = (
            f"https://api.aladhan.com/v1/timings/{date_str}?"
            f"latitude={lat}&longitude={lon}&method={method}&school={school}"
        )
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Hyprland Prayer Widget)"})
            with urllib.request.urlopen(req, timeout=4) as resp:
                data = json.loads(resp.read().decode())["data"]
                source = "api"
        except Exception as e:
            print(f"API fetch notice: {e}, falling back to cache/offline...", file=sys.stderr)

    if not data and os.path.exists(CACHE_PATH):
        try:
            with open(CACHE_PATH, "r", encoding="utf-8") as f:
                cached = json.load(f)
                if cached.get("date_check") == str(today):
                    cached["source"] = "cache"
                    # Recompute dynamic state for current exact second
                    state = compute_schedule_state(cached)
                    cached.update(state)
                    return cached
        except Exception:
            pass

    if data:
        raw = data["timings"]
        hijri_num = int(data["date"]["hijri"]["month"]["number"])
        raw_hijri_day = int(data["date"]["hijri"]["day"])
        hijri_year = data["date"]["hijri"]["year"]
        hijri_day = raw_hijri_day + hijri_offset
        hijri_month_name = HIJRI_MONTHS.get(hijri_num, data["date"]["hijri"]["month"]["en"])
        hijri_str = f"{hijri_day} {hijri_month_name} {hijri_year}"
        special_day = get_special_day(hijri_day, hijri_num)

        fajr = adjust_time(raw.get("Fajr", "05:06"), offsets.get("Fajr", 0))
        sunrise = adjust_time(raw.get("Sunrise", "06:32"), offsets.get("Sunrise", 0))
        dhuhr = adjust_time(raw.get("Dhuhr", "11:39"), offsets.get("Dhuhr", 0))
        asr = adjust_time(raw.get("Asr", "14:23"), offsets.get("Asr", 0))
        maghrib = adjust_time(raw.get("Maghrib", "16:46"), offsets.get("Maghrib", 0))
        isha = adjust_time(raw.get("Isha", "18:06"), offsets.get("Isha", 0))
        midnight = adjust_time(raw.get("Midnight", "23:39"), 0)
        tahajjud = adjust_time(raw.get("Lastthird", "01:56"), 0)
    else:
        source = "offline_calc"
        solar = calculate_solar_timings(lat, lon, tz_offset, today, method, school, offsets)
        fajr = solar["fajr"]
        sunrise = solar["sunrise"]
        dhuhr = solar["dhuhr"]
        asr = solar["asr"]
        maghrib = solar["maghrib"]
        isha = solar["isha"]
        midnight = solar["midnight"]
        tahajjud = solar["tahajjud"]

        h_y, h_m, h_d = gregorian_to_hijri(today, offset=hijri_offset)
        hijri_str = f"{h_d} {HIJRI_MONTHS.get(h_m, '')} {h_y}"
        special_day = get_special_day(h_d, h_m)

    timings_map = {
        "fajr": fajr,
        "sunrise": sunrise,
        "dhuhr": dhuhr,
        "asr": asr,
        "maghrib": maghrib,
        "isha": isha,
    }

    state = compute_schedule_state(timings_map)

    result = {
        "title": "Время намаза",
        "city": city,
        "date_check": str(today),
        "hijri_date": hijri_str,
        "special_day": special_day,
        "fajr": fajr,
        "sunrise": sunrise,
        "dhuhr": dhuhr,
        "asr": asr,
        "maghrib": maghrib,
        "isha": isha,
        "midnight": midnight,
        "tahajjud": tahajjud,
        "source": source,
        "updated_at": datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "config": cfg,
    }
    result.update(state)

    try:
        os.makedirs(os.path.dirname(CACHE_PATH), exist_ok=True)
        with open(CACHE_PATH, "w", encoding="utf-8") as f:
            json.dump(result, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"Cache write notice: {e}", file=sys.stderr)

    return result


def main():
    parser = argparse.ArgumentParser(description="Hyprland Prayer Times Service")
    parser.add_argument("--config", help="Path to config.json")
    parser.add_argument("--offline", action="store_true", help="Force offline calculation")
    parser.add_argument("--json", action="store_true", default=True, help="Output JSON")
    args = parser.parse_args()

    data = fetch_prayer_times(config_path=args.config, force_offline=args.offline)
    print(json.dumps(data, ensure_ascii=False))


if __name__ == "__main__":
    main()
