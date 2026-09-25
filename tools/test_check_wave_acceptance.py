"""Corrupt-data tests for the all-water recorder's independent verifier."""
import contextlib
import csv
import io
import tempfile
import unittest
from pathlib import Path

from check_wave_acceptance import total_water_pass, validate_case


class WaveBudgetChecks(unittest.TestCase):
    def test_owner_approved_boundaries_are_inclusive(self):
        self.assertTrue(total_water_pass(dict(total_upper_p95_ms=6, total_upper_p99_ms=7)))

    def test_p95_excess_fails_even_when_p99_is_inside_budget(self):
        self.assertFalse(total_water_pass(dict(total_upper_p95_ms=6.001, total_upper_p99_ms=6.5)))

    def test_p99_excess_fails_even_when_p95_is_inside_budget(self):
        self.assertFalse(total_water_pass(dict(total_upper_p95_ms=5.5, total_upper_p99_ms=7.001)))

    def test_retained_stress_result_meets_new_cpu_limits(self):
        # This checks policy only, not full phone/milestone acceptance.
        self.assertTrue(total_water_pass(dict(total_upper_p95_ms=5.938, total_upper_p99_ms=6.341)))


class WaveMeasurementChecks(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="ridge-wave-validator-")
        self.addCleanup(self.temporary.cleanup)
        self.directory = Path(self.temporary.name)
        self.frames = [dict(process_frame=10, frame_usec=16000, physics_ticks=2,
            controller_usec=1000, runtime_usec=100, emitter_usec=200,
            coordinator_usec=10, effects_upper_usec=80, audio_upper_usec=40,
            hud_usec=10, flat_usec=0, total_upper_usec=1440,
            wave_query_usec=200, gpu_ms=2, render_cpu_ms=.1)]
        self.ticks = [dict(process_frame=10, physics_tick=index,
            controller_usec=500, runtime_usec=50, emitter_usec=100,
            coordinator_usec=5, wave_query_usec=100) for index in (20, 21)]
        self.summary = dict(case="fixture", frames=1, fps=62.5, over_33ms=0, gpu_valid=True)
        for column in ("frame", "controller", "runtime", "emitter", "coordinator", "effects_upper", "audio_upper", "hud", "flat", "total_upper", "wave_query", "gpu", "render_cpu"):
            unit = "ms" if column in ("gpu", "render_cpu") else "usec"
            value = self.frames[0][column + "_" + unit] / (1 if unit == "ms" else 1000)
            for quantile in (95, 99, 100):
                self.summary[f"{column}_p{quantile}_ms"] = value

    def check(self):
        for name, rows in [("frames", self.frames), ("ticks", self.ticks)]:
            with (self.directory / ("fixture_" + name + ".csv")).open("w") as stream:
                writer = csv.DictWriter(stream, rows[0].keys())
                writer.writeheader()
                writer.writerows(rows)
        with contextlib.redirect_stdout(io.StringIO()):
            return validate_case(self.directory, self.summary)

    def test_valid_components_are_counted_once(self):
        self.check()

    def two_timestamped_frames(self):
        self.frames[0]["end_usec"] = 16000
        self.frames.append(dict(self.frames[0], process_frame=11, end_usec=32000))
        self.ticks.extend([dict(row, process_frame=11, physics_tick=row["physics_tick"] + 2)
                           for row in self.ticks[:]])
        self.summary["frames"] = 2

    def test_frame_timestamps_agree_with_elapsed_intervals(self):
        self.two_timestamped_frames()
        self.check()

    def test_inconsistent_frame_timestamp_is_rejected(self):
        self.two_timestamped_frames()
        self.frames[1]["end_usec"] += 1
        with self.assertRaisesRegex(ValueError, "inconsistent frame clock"):
            self.check()

    def test_nested_query_cannot_be_counted_twice(self):
        self.frames[0]["total_upper_usec"] += 200
        with self.assertRaisesRegex(ValueError, "overlapping/missing total"):
            self.check()

    def test_duplicate_tick_is_rejected(self):
        self.ticks[1]["physics_tick"] = 20
        with self.assertRaisesRegex(ValueError, "duplicate tick"):
            self.check()

    def test_unassociated_tick_is_rejected(self):
        self.ticks[1]["process_frame"] = 11
        with self.assertRaisesRegex(ValueError, "unassociated tick"):
            self.check()

    def test_missing_component_is_rejected(self):
        self.frames[0]["emitter_usec"] = 0
        with self.assertRaisesRegex(ValueError, "component sum"):
            self.check()

    def test_bad_p99_is_rejected(self):
        self.summary["total_upper_p99_ms"] = .01
        with self.assertRaisesRegex(ValueError, "incorrect total_upper_p99"):
            self.check()

    def test_zero_gpu_cannot_pass(self):
        self.summary["gpu_valid"] = False
        with self.assertRaisesRegex(ValueError, "GPU validity"):
            self.check()


if __name__ == "__main__":
    unittest.main()
