import unittest
from unittest.mock import Mock, patch

from water_hitch_windows import clocks, sql, windows


class HitchWindows(unittest.TestCase):
    LINE = ('1790256168.449 1094 1195 I godot : water hitch clock '
            '{"case":"one","ticks_usec":2884960,"unix_seconds":1790256168.4497}')

    def test_decimal_clock_preserves_printed_precision(self):
        self.assertEqual(clocks(self.LINE, 1094, 1195)["one"], 1790256165564740000)

    def test_other_vulkan_worker_is_not_selected_by_name(self):
        with self.assertRaises(ValueError):
            clocks(self.LINE, 1094, 1196)
        with self.assertRaises(ValueError):
            clocks(self.LINE, 1093, 1195)

    def test_duplicate_anchors_rejected(self):
        with self.assertRaises(ValueError):
            clocks(self.LINE + "\n" + self.LINE, 1094, 1195)

    def test_sql_keeps_absolute_span_and_checks_coverage(self):
        result = sql([("one's frame", 123456789000000, 123456823000000)], 1094, 1195, 10)
        self.assertIn("one''s frame", result)
        self.assertIn("123456789000000,123456823000000", result)
        self.assertIn("WHERE t.tid=1195 AND p.pid=1094", result)
        self.assertIn("HAVING ABS(uncovered_ns)>0", result)

    def test_window_alignment_and_deduplication(self):
        directory = Mock()
        directory.__truediv__ = Mock(return_value=Mock(read_text=lambda: '[{"case":"one"}]'))
        tick = {"tick": 1, "end_usec": 40000, "water_usec": 100, "physics_callbacks_usec": 5100,
                "stalled": 1, "sinking": 1, "flooding": 1}
        frame = {"frame": 2, "end_usec": 40000, "interval_usec": 34000,
                 "first_tick": 1, "last_tick": 1, "ticks": 1, "water_usec": 100}
        with patch("water_hitch_windows.rows", side_effect=[[tick], [frame]]):
            result = windows(directory, {"one": 100_000_000}, 10_000_000)
        self.assertEqual(result, [("one/frame/2", 96_000_000, 130_000_000),
                                  ("one/physics/1", 124_900_000, 130_000_000)])

    def test_missing_case_clock_is_an_error(self):
        directory = Mock()
        directory.__truediv__ = Mock(return_value=Mock(read_text=lambda: '[{"case":"one"}]'))
        with self.assertRaises(ValueError):
            windows(directory, {}, 0)


if __name__ == "__main__":
    unittest.main()
