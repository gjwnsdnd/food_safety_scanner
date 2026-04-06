from __future__ import annotations

from typing import Optional

from motor.motor_asyncio import AsyncIOMotorClient, AsyncIOMotorDatabase


class DBService:
    def __init__(self, uri: str, db_name: str):
        self._uri = uri
        self._db_name = db_name
        self.client: Optional[AsyncIOMotorClient] = None
        self.db: Optional[AsyncIOMotorDatabase] = None

    async def connect(self) -> None:
        if self.client is not None and self.db is not None:
            return

        self.client = AsyncIOMotorClient(self._uri)
        await self.client.admin.command("ping")
        self.db = self.client[self._db_name]

    async def disconnect(self) -> None:
        if self.client is None:
            return

        self.client.close()
        self.client = None
        self.db = None

    async def check_connection(self) -> bool:
        try:
            if self.client is None:
                await self.connect()
            if self.client is None:
                return False
            await self.client.admin.command("ping")
            return True
        except Exception:
            return False


_db_service: Optional[DBService] = None


def init_db_service(uri: str, db_name: str) -> None:
    global _db_service
    _db_service = DBService(uri=uri, db_name=db_name)


def get_db_service() -> DBService:
    if _db_service is None:
        raise RuntimeError("DB service is not initialized.")
    return _db_service
