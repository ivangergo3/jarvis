import unittest
from tags import normalize_tag


class NormalizeTagTests(unittest.TestCase):
    def test_trim_outer_whitespace(self):
        self.assertEqual(normalize_tag(" \tAlpha\n "), "alpha")

    def test_lowercase(self):
        self.assertEqual(normalize_tag("ReLeAsE"), "release")

    def test_preserve_internal_spaces(self):
        self.assertEqual(normalize_tag("  Team  Blue Sky  "), "team  blue sky")

    def test_empty(self):
        self.assertEqual(normalize_tag(""), "")

    def test_whitespace_only(self):
        self.assertEqual(normalize_tag(" \t\n "), "")

    def test_already_normalized(self):
        self.assertEqual(normalize_tag("team blue"), "team blue")


if __name__ == "__main__":
    unittest.main()
