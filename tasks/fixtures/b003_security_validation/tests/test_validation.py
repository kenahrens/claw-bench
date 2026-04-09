import unittest

from src.validation import normalize_username


class ValidationTests(unittest.TestCase):
    def test_nominal_name(self):
        self.assertEqual(normalize_username("  Alice_01  "), "alice_01")

    def test_too_short(self):
        with self.assertRaises(ValueError):
            normalize_username("ab")


if __name__ == "__main__":
    unittest.main()
