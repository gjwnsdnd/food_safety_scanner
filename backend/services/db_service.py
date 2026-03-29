import logging
from typing import Any

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase

logger = logging.getLogger(__name__)


class MongoDBService:
    # MongoDB 연결/조회/저장 로직을 담당합니다.
    def __init__(self, uri: str, db_name: str) -> None:
        self._uri = uri
        self._db_name = db_name
        self._client: AsyncIOMotorClient | None = None
        self._db: AsyncIOMotorDatabase | None = None

    async def connect(self) -> None:
        # 애플리케이션 시작 시 DB 연결을 초기화합니다.
        if self._client is not None:
            return

        self._client = AsyncIOMotorClient(self._uri)
        self._db = self._client[self._db_name]
        logger.info("MongoDB connected: %s/%s", self._uri, self._db_name)

    async def disconnect(self) -> None:
        # 애플리케이션 종료 시 연결을 정리합니다.
        if self._client is not None:
            self._client.close()
            self._client = None
            self._db = None
            logger.info("MongoDB disconnected")

    @property
    def db(self) -> AsyncIOMotorDatabase:
        if self._db is None:
            raise RuntimeError("MongoDB is not connected")
        return self._db

    async def get_ingredient_by_name(self, name: str) -> dict[str, Any] | None:
        # 특정 성분 정보를 조회합니다.
        return await self.db["ingredients"].find_one({"name": name}, {"_id": 0})

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


db_service: MongoDBService | None = None


def init_db_service(uri: str, db_name: str) -> MongoDBService:
    # main.py에서 서비스 싱글턴을 초기화합니다.
    global db_service
    db_service = MongoDBService(uri=uri, db_name=db_name)
    return db_service


def get_db_service() -> MongoDBService:
    if db_service is None:
        raise RuntimeError("DB service is not initialized")
    return db_service
