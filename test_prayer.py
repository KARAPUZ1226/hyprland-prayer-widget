#!/usr/bin/env python3
"""
Unit tests for Hyprland Prayer Times Service
"""

import datetime
import unittest
import os
import sys

# Ensure local module is importable
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_prayer


class TestPrayerService(unittest.TestCase):
    def test_solar_timings(self):
        """Test astronomical calculation for Gudermes on 2026-11-02."""
        offsets = {"Fajr": 11, "Sunrise": -2, "Dhuhr": 51, "Asr": 22, "Maghrib": 5, "Isha": 14}
        date = datetime.date(2026, 11, 2)
        res = fetch_prayer.calculate_solar_timings(
            lat=43.3506,
            lon=46.0953,
            tz_offset=3.0,
            date=date,
            method=14,
            school=0,
            offsets=offsets
        )
        self.assertIn("fajr", res)
        self.assertIn("sunrise", res)
        self.assertIn("dhuhr", res)
        self.assertIn("asr", res)
        self.assertIn("maghrib", res)
        self.assertIn("isha", res)
        self.assertIn("midnight", res)
        self.assertIn("tahajjud", res)

        # Check expected ranges
        self.assertTrue(res["fajr"].startswith("05:"))
        self.assertTrue(res["sunrise"].startswith("06:"))
        self.assertTrue(res["dhuhr"].startswith("12:"))
        self.assertTrue(res["asr"].startswith("14:"))
        self.assertTrue(res["maghrib"].startswith("16:"))
        self.assertTrue(res["isha"].startswith("18:"))

    def test_adjust_time(self):
        """Test time adjustment with minute deltas."""
        self.assertEqual(fetch_prayer.adjust_time("12:00", 30), "12:30")
        self.assertEqual(fetch_prayer.adjust_time("12:00", -15), "11:45")
        self.assertEqual(fetch_prayer.adjust_time("23:50", 20), "00:10")
        self.assertEqual(fetch_prayer.adjust_time("00:10", -20), "23:50")

    def test_gregorian_to_hijri(self):
        """Test Gregorian to Hijri algorithm."""
        y, m, d = fetch_prayer.gregorian_to_hijri(datetime.date(2026, 11, 2), offset=1)
        self.assertEqual(y, 1448)
        self.assertEqual(m, 5) # Jumada al-Ula
        self.assertTrue(21 <= d <= 24)

    def test_schedule_state(self):
        """Test current/next prayer detection and progress calculation."""
        timings = {
            "fajr": "05:00",
            "sunrise": "06:30",
            "dhuhr": "12:00",
            "asr": "15:00",
            "maghrib": "18:00",
            "isha": "19:30"
        }
        # Test noon (12:30) -> Current Dhuhr, Next Asr
        dt_midday = datetime.datetime(2026, 11, 2, 12, 30, 0)
        state = fetch_prayer.compute_schedule_state(timings, now=dt_midday)
        self.assertEqual(state["current_prayer"]["key"], "dhuhr")
        self.assertEqual(state["next_prayer"]["key"], "asr")
        self.assertEqual(state["next_prayer"]["diff_minutes"], 150)
        self.assertEqual(state["next_prayer"]["remaining_str"], "02:30")
        self.assertAlmostEqual(state["progress"], 30 / 180, places=2)

        # Test late night (22:00) -> Current Isha, Next Fajr
        dt_night = datetime.datetime(2026, 11, 2, 22, 0, 0)
        state_night = fetch_prayer.compute_schedule_state(timings, now=dt_night)
        self.assertEqual(state_night["current_prayer"]["key"], "isha")
        self.assertEqual(state_night["next_prayer"]["key"], "fajr")
        self.assertEqual(state_night["next_prayer"]["diff_minutes"], 420)
        self.assertTrue(0.0 <= state_night["progress"] <= 1.0)

    def test_special_days(self):
        """Test Islamic special days and Friday detection."""
        self.assertEqual(fetch_prayer.get_special_day(1, 10), "Ураза-Байрам")
        self.assertEqual(fetch_prayer.get_special_day(10, 12), "Курбан-Байрам")
        self.assertEqual(fetch_prayer.get_special_day(27, 9), "Ляйлят уль-Кадр")
        self.assertEqual(fetch_prayer.get_special_day(15, 9), "Рамадан")

    def test_offline_fallback(self):
        """Test that force_offline returns a complete valid payload."""
        res = fetch_prayer.fetch_prayer_times(force_offline=True)
        required_keys = [
            "city", "hijri_date", "fajr", "sunrise", "dhuhr", "asr",
            "maghrib", "isha", "current_prayer", "next_prayer", "progress"
        ]
        for key in required_keys:
            self.assertIn(key, res)
        self.assertTrue(0.0 <= res["progress"] <= 1.0)


if __name__ == "__main__":
    unittest.main()
