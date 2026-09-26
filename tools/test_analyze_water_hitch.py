import copy
import unittest
from analyze_water_hitch import event_context, validate


class HitchValidation(unittest.TestCase):
    def setUp(self):
        self.ticks = [{"tick": index, "water_usec": index * 2} for index in range(1, 6)]
        self.frames = [{"frame": 1, "first_tick": 1, "last_tick": 2, "ticks": 2, "water_usec": 6},
                       {"frame": 2, "first_tick": 3, "last_tick": 4, "ticks": 2, "water_usec": 14}]

    def test_partial_final_frame_is_allowed(self):
        self.assertEqual(len(validate(self.ticks, self.frames)), 5)

    def test_wrong_sum_rejected(self):
        self.frames[1]["water_usec"] += 1
        with self.assertRaises(ValueError):
            validate(self.ticks, self.frames)

    def test_duplicate_ticks_rejected(self):
        self.frames[1].update(first_tick=2, last_tick=3, water_usec=10)
        with self.assertRaises(ValueError):
            validate(self.ticks, self.frames)

    def test_gap_rejected(self):
        ticks = copy.deepcopy(self.ticks)
        del ticks[2]
        with self.assertRaises(ValueError):
            validate(ticks, self.frames)

    def test_empty_rejected(self):
        with self.assertRaises(ValueError):
            validate([], self.frames)


class HitchEventContext(unittest.TestCase):
    def capture(self, count=12):
        ticks = [{"tick": i, "end_usec": i * 40000, "water_usec": 100,
                  "stalled": int(i >= 3), "sinking": int(i >= 4),
                  "flooding": float(i >= 5)} for i in range(1, count + 1)]
        frames = [{"frame": i, "end_usec": i * 40000, "interval_usec": 40000,
                   "first_tick": i, "last_tick": i, "ticks": 1, "water_usec": 100,
                   "objects": 10 + i, "nodes": 2, "resources": 3,
                   "static_bytes": 1000, "loop_starts": 1, "water_entries": 1,
                   "thumps": 0} for i in range(1, count + 1)]
        return ticks, frames

    def test_initial_state_is_not_a_transition(self):
        ticks, frames = self.capture()
        for row in ticks:
            row.update(stalled=1, sinking=1, flooding=1)
        result = event_context(ticks, frames)
        self.assertEqual(result["transition_windows"], [])
        self.assertEqual(result["state_tick_counts"]["stalled_full"], len(ticks))

    def test_changes_use_containing_frame_and_include_recovery(self):
        ticks, frames = self.capture()
        ticks[-1].update(stalled=0, sinking=0, flooding=0)
        result = event_context(ticks, frames)
        changes = result["transition_windows"]
        self.assertEqual(len(changes), 6)
        self.assertEqual(changes[0]["state"], "stalled")
        self.assertEqual(changes[0]["frame"]["frame"], 3)
        self.assertFalse(changes[-1]["after"])
        self.assertEqual(sum(result["state_tick_counts"].values()), len(ticks))

    def test_every_long_frame_is_retained_not_only_top_eight(self):
        ticks, frames = self.capture()
        result = event_context(ticks, frames)
        self.assertEqual(len(result["all_long_frames"]), 12)
        self.assertEqual(result["all_long_frames"][1]["net_monitor_changes"]["objects"], 1)

    def test_nearby_window_includes_interval_overlapping_boundary(self):
        ticks, frames = self.capture(6)
        # The frame ends outside the +/-25ms window but overlaps it.
        frames[3]["interval_usec"] = 50000
        result = event_context(ticks, frames, radius_usec=25000)
        self.assertEqual(result["transition_windows"][0]["nearby_max_ms"], 50)

    def test_tail_selection_uses_33_point_3_not_rounded_one_thirtieth(self):
        ticks, frames = self.capture(2)
        frames[0]["interval_usec"] = 33300
        frames[1]["interval_usec"] = 33301
        self.assertEqual([f["frame"] for f in event_context(ticks, frames)["all_long_frames"]], [2])

    def test_transition_in_final_partial_frame_stays_unattributed(self):
        ticks, frames = self.capture(3)
        result = event_context(ticks, frames[:-1])
        self.assertIsNone(result["transition_windows"][0]["frame"])


if __name__ == "__main__":
    unittest.main()
