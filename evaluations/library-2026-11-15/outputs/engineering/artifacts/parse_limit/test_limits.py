import unittest
from limits import parse_limit


class ParseLimitTests(unittest.TestCase):
    def test_accepted_values(self):
        for text, expected in [("1", 1), ("100", 100), ("42", 42), ("  7\t\n", 7), ("0005", 5), ("0" * 5000 + "1", 1)]:
            with self.subTest(text=text[:30]):
                actual = parse_limit(text)
                self.assertIs(type(actual), int)
                self.assertEqual(actual, expected)

    def test_invalid_syntax(self):
        for text in ["", " \t", "+1", "-1", "1.0", "1e1", "1_0", "1 0", "abc", "0x10"]:
            with self.subTest(text=text):
                with self.assertRaises(ValueError):
                    parse_limit(text)

    def test_range(self):
        for text in ["0", "000", "101", "999", "9" * 5000]:
            with self.subTest(text=text[:30]):
                with self.assertRaises(ValueError):
                    parse_limit(text)

    def test_non_string_input(self):
        for value in [None, 1, True, 1.0, b"1"]:
            with self.subTest(value=value):
                with self.assertRaises(ValueError):
                    parse_limit(value)


if __name__ == "__main__":
    unittest.main()
