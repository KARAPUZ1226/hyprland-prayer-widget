#!/usr/bin/env python3
import unittest
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import fetch_prayer

class TestPrayerService(unittest.TestCase):
    def test_adjust_time(self):
        self.assertEqual(fetch_prayer.adjust_time("12:00", 30), "12:30")
        self.assertEqual(fetch_prayer.adjust_time("12:00", -15), "11:45")
        self.assertEqual(fetch_prayer.adjust_time("23:50", 20), "00:10")

    def test_special_days(self):
        self.assertEqual(fetch_prayer.get_special_day(1, 10), "Ураза-Байрам")
        self.assertEqual(fetch_prayer.get_special_day(10, 12), "Курбан-Байрам")

    def test_fetch_and_save(self):
        res = fetch_prayer.fetch_and_save()
        self.assertIn("fajr", res)
        self.assertIn("sunrise", res)
        self.assertIn("dhuhr", res)
        self.assertIn("asr", res)
        self.assertIn("maghrib", res)
        self.assertIn("isha", res)
        self.assertIn("hijri_date", res)

if __name__ == "__main__":
    unittest.main()
