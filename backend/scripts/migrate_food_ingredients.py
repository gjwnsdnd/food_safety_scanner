from __future__ import annotations

import asyncio
import logging
from datetime import UTC, datetime

from dotenv import load_dotenv
from motor.motor_asyncio import AsyncIOMotorClient
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db_name: str = "food_safety"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")


logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)


SOURCE_COLLECTION = "food_ingredients"
BACKUP_COLLECTION = "food_ingredients_backup"


def transform_document(document: dict) -> dict:
    """우리 스키마에 맞춰 문서를 변환한다."""
    return {
        "name": str(document.get("name", "")).strip(),
        "description": "",
        "caution": "",
        "uses": "",
    }


async def create_backup(db) -> int:
    source = db[SOURCE_COLLECTION]
    backup = db[BACKUP_COLLECTION]

    existing_backup_count = await backup.count_documents({})
    if existing_backup_count > 0:
        timestamp = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
        archived_name = f"{BACKUP_COLLECTION}_{timestamp}"
        logger.warning(
            "기존 백업 컬렉션이 존재하여 %s 로 이름을 변경합니다. count=%d",
            archived_name,
            existing_backup_count,
        )
        await backup.rename(archived_name)
        backup = db[BACKUP_COLLECTION]

    logger.info("백업 시작: %s -> %s", SOURCE_COLLECTION, BACKUP_COLLECTION)
    await db.command(
        "aggregate",
        SOURCE_COLLECTION,
        pipeline=[{"$match": {}}, {"$out": BACKUP_COLLECTION}],
        cursor={},
    )

    backup_count = await backup.count_documents({})
    logger.info("백업 완료: backup_count=%d", backup_count)
    return backup_count


async def rollback_from_backup(db) -> None:
    source = db[SOURCE_COLLECTION]
    backup = db[BACKUP_COLLECTION]

    backup_count = await backup.count_documents({})
    if backup_count == 0:
        raise RuntimeError("롤백 실패: 백업 컬렉션이 비어 있습니다.")

    logger.warning("롤백 시작: %s -> %s", BACKUP_COLLECTION, SOURCE_COLLECTION)
    await source.drop()
    await db.command(
        "aggregate",
        BACKUP_COLLECTION,
        pipeline=[{"$match": {}}, {"$out": SOURCE_COLLECTION}],
        cursor={},
    )
    restored_count = await source.count_documents({})
    logger.warning("롤백 완료: restored_count=%d", restored_count)


async def migrate() -> None:
    load_dotenv("backend/.env")
    load_dotenv()
    settings = Settings()

    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.mongodb_db_name]
    source = db[SOURCE_COLLECTION]

    try:
        before_count = await source.count_documents({})
        logger.info("마이그레이션 시작: db=%s, collection=%s, before_count=%d", settings.mongodb_db_name, SOURCE_COLLECTION, before_count)

        if before_count == 0:
            logger.warning("마이그레이션 중단: source 컬렉션에 문서가 없습니다.")
            return

        backup_count = await create_backup(db)
        if backup_count != before_count:
            raise RuntimeError(
                f"백업 문서 수 불일치: before_count={before_count}, backup_count={backup_count}"
            )

        cursor = source.find({})
        transformed_documents: list[dict] = []

        async for document in cursor:
            transformed = transform_document(document)
            # name이 비어 있으면 품질 이슈이므로 원본 name 최대한 보존
            if not transformed["name"]:
                transformed["name"] = str(document.get("eng_name", "")).strip() or "UNKNOWN"
            transformed_documents.append(transformed)

        if not transformed_documents:
            raise RuntimeError("변환 결과가 비어 있습니다.")

        # 전체 교체(원자성 보장을 위해 백업이 있는 상태에서 drop+insert)
        await source.drop()
        insert_result = await source.insert_many(transformed_documents, ordered=False)

        after_count = await source.count_documents({})
        logger.info("마이그레이션 완료: inserted=%d, after_count=%d", len(insert_result.inserted_ids), after_count)

        sample_docs = await source.find({}, {"_id": 0}).limit(3).to_list(length=3)
        logger.info("변환된 샘플 데이터(3개): %s", sample_docs)

        logger.info("전/후 요약: before_count=%d -> after_count=%d", before_count, after_count)

    except Exception:
        logger.exception("마이그레이션 중 오류 발생")
        try:
            await rollback_from_backup(db)
        except Exception:
            logger.exception("자동 롤백 실패")
        raise
    finally:
        client.close()


if __name__ == "__main__":
    asyncio.run(migrate())
