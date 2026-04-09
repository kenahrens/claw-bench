import unittest

from src.stats import moving_average


class HiddenMovingAverageTests(unittest.TestCase):
    def test_window_three(self):
        self.assertEqual(moving_average([3, 6, 9, 12], 3), [6.0, 9.0])

    def test_invalid_window(self):
        with self.assertRaises(ValueError):
            moving_average([1, 2, 3], 0)


if __name__ == "__main__":
    unittest.main()
