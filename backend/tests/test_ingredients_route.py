import unittest
from unittest.mock import patch

from backend.routes.ingredients import get_ingredients


class _FakeCursor:
    def __init__(self, documents):
        self._documents = documents

    async def to_list(self, length):
        return self._documents[:length]


class _FakeCollection:
    def __init__(self, documents):
        self._documents = documents
        self.query = None
        self.projection = None

    def find(self, query, projection):
        self.query = query
        self.projection = projection
        return _FakeCursor(self._documents)


class _FakeDBService:
    def __init__(self, collection):
        self.db = {"food_ingredients": collection}


class IngredientsRouteTests(unittest.IsolatedAsyncioTestCase):
    async def test_get_ingredients_returns_normalized_deduplicated_sorted_names(self):
        collection = _FakeCollection(
            [
                {"name": "D-말티톨"},
                {"name": "말티톨"},
                {"name": "L-아스코르빈산(비세균성)"},
                {"name": "DL-자일리톨"},
                {"name": "N-아세틸글루코사민"},
                {"name": " "},
            ]
        )
        fake_db_service = _FakeDBService(collection)

        with patch("backend.routes.ingredients.get_db_service", return_value=fake_db_service):
            response = await get_ingredients(category=None)

        self.assertEqual(response, {"ingredients": ["말티톨", "아세틸글루코사민", "아스코르빈산", "자일리톨"]})
        self.assertEqual(collection.query, {})

    async def test_get_ingredients_applies_category_filter_before_normalizing(self):
        collection = _FakeCollection([{"name": "D-말티톨"}])
        fake_db_service = _FakeDBService(collection)

        with patch("backend.routes.ingredients.get_db_service", return_value=fake_db_service):
            response = await get_ingredients(category="알레르기")

        self.assertEqual(response, {"ingredients": ["말티톨"]})
        self.assertEqual(collection.query, {"categories": "알레르기"})


if __name__ == "__main__":
    unittest.main()
