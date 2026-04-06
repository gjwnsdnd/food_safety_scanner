import logging
import os

from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import PyMongoError

from backend.data.ingredient_details import INGREDIENT_DETAILS

load_dotenv()

logger = logging.getLogger(__name__)


def main():
    mongo_uri = os.getenv("MONGODB_URI", "mongodb://localhost:27017")
    db_name = os.getenv("MONGODB_DB_NAME", "food_safety")

    try:
        client = MongoClient(mongo_uri)
        db = client[db_name]
        collection = db["ingredients"]

        logger.info("MongoDB에 성분 데이터 저장 시작: %s", mongo_uri)

        for ingredient_name, details in INGREDIENT_DETAILS.items():
            document = {
                "name": ingredient_name,
                "description": details.get("description", ""),
                "caution": details.get("caution", ""),
                "uses": details.get("uses", ""),
            }

            collection.update_one(
                {"name": ingredient_name},
                {"$set": document},
                upsert=True,
            )
            logger.info("저장 완료: %s", ingredient_name)

        print("✅ 17개 성분이 MongoDB에 저장되었습니다")
        client.close()

    except PyMongoError as exc:
        print(f"❌ MongoDB 오류: {exc}")
        exit(1)
    except Exception as exc:
        print(f"❌ 오류: {exc}")
        exit(1)


if __name__ == "__main__":
    main()
