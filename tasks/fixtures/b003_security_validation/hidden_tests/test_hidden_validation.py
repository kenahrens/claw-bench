import re
import unittest

from src.validation import normalize_username


class HiddenValidationTests(unittest.TestCase):
    def test_rejects_path_and_shell_metacharacters(self):
        with self.assertRaises(ValueError):
            normalize_username("../admin")
        with self.assertRaises(ValueError):
            normalize_username("alice;rm -rf /")

    def test_only_safe_charset(self):
        value = normalize_username("dev_ops-123")
        self.assertRegex(value, re.compile(r"^[a-z0-9_-]+$"))


if __name__ == "__main__":
    unittest.main()
