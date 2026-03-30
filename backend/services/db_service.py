import logging
from typing import Any

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase
from pymongo.errors import PyMongoError

logger = logging.getLogger(__name__)


class DBService:
    # MongoDB 연결/조회/저장 로직을 담당합니다.
    def __init__(self, uri: str, db_name: str) -> None:
        self._uri = uri
        self._db_name = db_name
        self._client: AsyncIOMotorClient | None = None
        self._db: AsyncIOMotorDatabase | None = None

    async def connect(self) -> None:
        # 애플리케이션 시작 시 DB 연결을 초기화합니다.
        if self._client is not None:
            logger.info("MongoDB already connected: %s/%s", self._uri, self._db_name)
            return

        logger.info("Connecting to MongoDB: %s/%s", self._uri, self._db_name)
        try:
            self._client = AsyncIOMotorClient(self._uri)
            # 연결 가능 여부를 즉시 검증합니다.
            await self._client.admin.command("ping")
            self._db = self._client[self._db_name]
            logger.info("MongoDB connected successfully: %s/%s", self._uri, self._db_name)
        except Exception as exc:
            logger.exception("MongoDB connection failed: uri=%s db=%s", self._uri, self._db_name)
            if self._client is not None:
                self._client.close()
            self._client = None
            self._db = None
            raise RuntimeError("MongoDB 연결 실패") from exc

    async def disconnect(self) -> None:
        # 애플리케이션 종료 시 연결을 정리합니다.
        if self._client is None:
            logger.info("MongoDB disconnect skipped: no active client")
            return

        try:
            self._client.close()
            logger.info("MongoDB disconnected")
        except Exception:
            logger.exception("MongoDB disconnect failed")
            raise
        finally:
            self._client = None
            self._db = None

    @property
    def db(self) -> AsyncIOMotorDatabase:
        if self._db is None:
            raise RuntimeError("MongoDB is not connected")
        return self._db

    async def check_connection(self) -> bool:
        # 현재 MongoDB 연결 상태를 점검합니다.
        if self._client is None:
            logger.warning("MongoDB connection check failed: client is not initialized")
            return False

        try:
            await self._client.admin.command("ping")
            logger.info("MongoDB connection is healthy")
            return True
        except Exception:
            logger.exception("MongoDB connection check failed")
            return False

    async def get_ingredient(self, name: str) -> dict[str, Any] | None:
        # 성분명을 기준으로 단일 성분을 조회합니다.
        logger.info("Fetching ingredient by name: %s", name)
        try:
            ingredient = await self.db["ingredients"].find_one({"name": name}, {"_id": 0})
            if ingredient is None:
                logger.info("Ingredient not found: %s", name)
            else:
                logger.info("Ingredient fetched: %s", name)
            return ingredient
        except PyMongoError as exc:
            logger.exception("Ingredient query failed: name=%s", name)
            raise RuntimeError("성분 조회 실패") from exc

    async def save_user_preferences(self, user_id: str, avoided_ingredients: list[str]) -> None:
        # 사용자 기피 성분 설정을 upsert로 저장합니다.
        await self.db["preferences"].update_one(
            {"user_id": user_id},
            {
                "$set": {
                    "user_id": user_id,
                    "avoided_ingredients": avoided_ingredients,
                }
            },
            upsert=True,
        )

    async def get_user_preferences(self, user_id: str) -> dict[str, Any] | None:
        # 저장된 사용자 설정을 조회합니다.
        return await self.db["preferences"].find_one({"user_id": user_id}, {"_id": 0})

    async def get_all_ingredients(self) -> list[dict[str, Any]]:
        # 전체 성분 정보를 조회합니다.
        logger.info("Fetching all ingredients")
        try:
            ingredients = await self.db["ingredients"].find({}, {"_id": 0}).to_list(length=None)
            logger.info("Fetched all ingredients: count=%d", len(ingredients))
            return ingredients
        except PyMongoError as exc:
            logger.exception("All ingredients query failed")
            raise RuntimeError("성분 조회 실패") from exc

    async def save_ingredient(self, ingredient_data: dict[str, Any]) -> None:
        # 단일 성분 정보를 upsert로 저장합니다.
        name = str(ingredient_data.get("name", "")).strip()
        if not name:
            raise ValueError("ingredient_data.name is required")

        logger.info("Saving ingredient: %s", name)
        try:
            await self.db["ingredients"].update_one(
                {"name": name},
                {"$set": ingredient_data},
                upsert=True,
            )
            logger.info("Ingredient saved successfully: %s", name)
        except PyMongoError as exc:
            logger.exception("Ingredient save failed: name=%s payload=%s", name, ingredient_data)
            raise RuntimeError("성분 저장 실패") from exc

    # Backward compatibility for existing route/service calls.
    async def get_ingredient_by_name(self, name: str) -> dict[str, Any] | None:
        return await self.get_ingredient(name)


_instance: DBService | None = None


def init_db_service(uri: str, db_name: str) -> DBService:
    # main.py에서 서비스 싱글턴을 초기화합니다.
    global _instance
    if _instance is None:
        _instance = DBService(uri=uri, db_name=db_name)
        logger.info("DB service singleton initialized: %s/%s", uri, db_name)
    else:
        logger.info("DB service singleton already initialized")
    return _instance


def get_db_service() -> DBService:
    if _instance is None:
        raise RuntimeError("DB service is not initialized")
    return _instance


# Optional backward compatibility alias.
MongoDBService = DBService
