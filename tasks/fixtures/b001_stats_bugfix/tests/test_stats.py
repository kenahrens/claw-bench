import unittest

from src.stats import moving_average


class MovingAverageTests(unittest.TestCase):
    def test_window_two(self):
        self.assertEqual(moving_average([2, 4, 6, 8], 2), [3.0, 5.0, 7.0])

    def test_small_input(self):
        self.assertEqual(moving_average([10], 2), [])


if __name__ == "__main__":
    unittest.main()
