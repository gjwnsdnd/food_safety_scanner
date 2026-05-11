import unittest

from backend.services.ingredient_normalizer import normalize_ingredient_name


class IngredientNormalizerTests(unittest.TestCase):
    def test_normalize_ingredient_name_rules(self):
        cases = [
            (" D-말티톨 ", "말티톨"),
            ("l – 아스코르빈산(비세균성)", "아스코르빈산"),
            ("D,L-자일리톨(테스트)(샘플)", "자일리톨"),
            ("DL   말티톨", "말티톨"),
            ("  말 티  톨  ", "말 티 톨"),
        ]

        for raw, expected in cases:
            with self.subTest(raw=raw):
                self.assertEqual(normalize_ingredient_name(raw), expected)


if __name__ == "__main__":
    unittest.main()
