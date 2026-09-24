import copy
import unittest
from analyze_water_hitch import validate


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


if __name__ == "__main__":
    unittest.main()
