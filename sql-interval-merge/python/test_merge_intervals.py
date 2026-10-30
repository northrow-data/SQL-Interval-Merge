"""Run with:  python -m unittest -v   (from the python/ folder)"""

import unittest

from merge_intervals import Hold, merge_holds, total_hold_days
from scenarios import AS_OF, SCENARIOS


class TestMergeHolds(unittest.TestCase):
    def test_scenarios(self):
        for ticket_id, name, open_date, close_date, raw_holds, exp_islands, exp_days in SCENARIOS:
            with self.subTest(f"{ticket_id:02d} {name}"):
                holds = [Hold(i, s, e) for i, (s, e) in enumerate(raw_holds, start=1)]
                islands, _ = merge_holds(holds, open_date, close_date, AS_OF)
                self.assertEqual(len(islands), exp_islands)
                self.assertEqual(total_hold_days(islands), exp_days)

    def test_bad_rows_are_reported(self):
        _, _, open_date, close_date, raw_holds, _, _ = SCENARIOS[7]  # scenario 8
        holds = [Hold(i, s, e) for i, (s, e) in enumerate(raw_holds, start=1)]
        _, rejected = merge_holds(holds, open_date, close_date, AS_OF)
        self.assertEqual([h.hold_id for h in rejected], [1])

    def test_input_order_does_not_matter(self):
        _, _, open_date, close_date, raw_holds, _, exp_days = SCENARIOS[9]
        forward = [Hold(i, s, e) for i, (s, e) in enumerate(raw_holds, start=1)]
        backward = list(reversed(forward))
        a, _ = merge_holds(forward, open_date, close_date, AS_OF)
        b, _ = merge_holds(backward, open_date, close_date, AS_OF)
        self.assertEqual(a, b)
        self.assertEqual(total_hold_days(a), exp_days)


if __name__ == "__main__":
    unittest.main(verbosity=2)
