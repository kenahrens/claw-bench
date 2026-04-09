import inspect
import unittest

from src import parser


class HiddenParserTests(unittest.TestCase):
    def test_handles_signs_and_blanks(self):
        self.assertEqual(parser.parse_csv_ints(" +1, , -2, +3 "), [1, -2, 3])
        self.assertEqual(parser.parse_pipe_ints(" +7 | | -8 | +9 "), [7, -8, 9])

    def test_deduplicated_logic(self):
        source = inspect.getsource(parser)
        self.assertIn("_parse_ints", source)


if __name__ == "__main__":
    unittest.main()
