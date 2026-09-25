import unittest

from report_wave_acceptance import gpu_pairs


class WaveGpuPairChecks(unittest.TestCase):
    @staticmethod
    def row(car="rally", round_index=0, mode=0, gpu=8, valid=True):
        return dict(car=car, round=round_index, mode=mode, gpu_p95_ms=gpu, gpu_valid=valid)

    def test_order_does_not_change_pairing_or_mix_cars_and_rounds(self):
        rows = [self.row(mode=2, gpu=8.6), self.row(),
                self.row(car="4x4", mode=2, gpu=2), self.row(round_index=1, gpu=3)]
        pairs = gpu_pairs(rows)
        self.assertEqual(len(pairs), 1)
        self.assertAlmostEqual(pairs[0]["delta_p95_ms"], .6)
        self.assertFalse(pairs[0]["inside_allocation"])

    def test_boundary_is_inclusive_and_missing_counter_is_not_a_pass(self):
        pairs = gpu_pairs([self.row(), self.row(mode=1, gpu=8.5), self.row(mode=2, gpu=0, valid=False)])
        self.assertTrue(pairs[0]["inside_allocation"])
        self.assertFalse(pairs[1]["valid"])
        self.assertFalse(pairs[1]["inside_allocation"])

    def test_duplicate_mode_is_not_silently_overwritten(self):
        with self.assertRaisesRegex(ValueError, "duplicate mode"):
            gpu_pairs([self.row(), self.row()])


if __name__ == "__main__":
    unittest.main()
