import unittest

from src.parser import parse_csv_ints, parse_pipe_ints


class ParserTests(unittest.TestCase):
    def test_csv_basic(self):
        self.assertEqual(parse_csv_ints("1, 2, 3"), [1, 2, 3])

    def test_pipe_basic(self):
        self.assertEqual(parse_pipe_ints("4|5|6"), [4, 5, 6])


if __name__ == "__main__":
    unittest.main()
