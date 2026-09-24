"""Small corruption fixtures for the independent timing-data validator."""

import contextlib
import csv
import io
import json
from pathlib import Path
import tempfile
import unittest

from check_water_measurements import check


class MeasurementChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ridge-water-validator-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.summary = {
            "case": "fixture", "samples": 4, "water_p95_ms": .4,
            "water_max_ms": .4, "queries": 52, "triangle_tests": 104,
            "query_total_ms": .12, "frame_samples": 2,
            "frame_p95_ms": 16.667, "frame_max_ms": 16.667,
            "water_frame_p95_ms": .4, "water_frame_max_ms": .4,
        }
        self.ticks = [[i + 1, cost, 13, 26, 30]
                      for i, cost in enumerate([100, 200, 100, 400])]
        self.frames = [[100, 16667, 2, 300], [101, 16666, 1, 400]]

    def validate(self, limit=None):
        (self.directory / "summary.json").write_text(json.dumps([self.summary]))
        for name, header, rows in [
            ("fixture.csv", ["physics_tick", "water_usec", "queries", "triangle_tests", "query_usec"], self.ticks),
            ("fixture_frames.csv", ["process_frame", "frame_usec", "physics_ticks", "water_usec"], self.frames),
        ]:
            with (self.directory / name).open("w", newline="") as stream:
                writer = csv.writer(stream)
                writer.writerow(header)
                writer.writerows(rows)
        with contextlib.redirect_stdout(io.StringIO()):
            return check(self.directory, limit)

    def test_complete_frame_and_tick_data_pass(self):
        self.assertEqual(self.validate(), 0)

    def test_empty_measurement_batch_is_not_a_pass(self):
        (self.directory / "summary.json").write_text("[]")
        with self.assertRaisesRegex(ValueError, "at least one measured case"):
            check(self.directory, None)

    def test_optional_gate_does_not_hide_consistent_over_budget_data(self):
        self.assertEqual(self.validate(.39), 2)
        self.assertEqual(self.validate(.4), 0)

    def test_original_tick_only_format_still_validates(self):
        for key in ["queries", "triangle_tests", "query_total_ms"]:
            del self.summary[key]
        self.assertEqual(self.validate(), 0)

    def test_duplicate_tick_is_rejected(self):
        self.ticks[2][0] = 2
        with self.assertRaisesRegex(ValueError, "repeated or skipped"):
            self.validate()

    def test_fabricated_triangle_total_is_rejected(self):
        self.summary["triangle_tests"] = 103
        with self.assertRaisesRegex(ValueError, "triangle_tests total"):
            self.validate()

    def test_frame_percentile_mismatch_is_rejected(self):
        self.summary["water_frame_p95_ms"] = .1
        with self.assertRaisesRegex(ValueError, "frame water_usec p95"):
            self.validate()

    def test_impossible_frame_tick_count_is_rejected(self):
        self.frames[0][2] = 8
        with self.assertRaisesRegex(ValueError, "impossible frame tick counts"):
            self.validate()

    def test_missing_frame_is_rejected(self):
        self.frames[1][0] = 102
        with self.assertRaisesRegex(ValueError, "skipped or duplicated process frame"):
            self.validate()


if __name__ == "__main__":
    unittest.main()
