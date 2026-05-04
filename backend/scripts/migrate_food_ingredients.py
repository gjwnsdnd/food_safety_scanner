from __future__ import annotations

import asyncio
import logging
import sys
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


FOOD_INGREDIENTS_COLLECTION = "food_ingredients"
FOOD_INGREDIENTS_BACKUP = "food_ingredients_backup"
INGREDIENTS_COLLECTION = "ingredients"
INGREDIENTS_BACKUP = "ingredients_backup"
FOOD_INGREDIENTS_BEFORE_STEP2 = "food_ingredients_before_step2"


def transform_document(document: dict) -> dict:
    """우리 스키마에 맞춰 문서를 변환한다. (Step 1)"""
    return {
        "name": str(document.get("name", "")).strip(),
        "description": "",
        "caution": "",
        "uses": "",
    }


def transform_ingredients_document(document: dict) -> dict:
    """ingredients 문서를 food_ingredients 스키마로 변환한다. (Step 2)"""
    return {
        "name": str(document.get("name", "")).strip(),
        "description": str(document.get("description", "")).strip(),
        "caution": str(document.get("caution", "")).strip(),
        "uses": str(document.get("uses", "")).strip(),
    }


async def is_step1_completed(db) -> bool:
    """Step 1 완료 여부를 확인한다."""
    food_ingredients = db[FOOD_INGREDIENTS_COLLECTION]
    doc = await food_ingredients.find_one({})
    if not doc:
        return False
    # Step 1에서 추가되는 필드들이 있는지 확인
    return all(key in doc for key in ["description", "caution", "uses"])


async def create_backup(db, source_collection: str, backup_collection: str) -> int:
    """지정된 컬렉션을 백업한다."""
    source = db[source_collection]
    backup = db[backup_collection]

    existing_backup_count = await backup.count_documents({})
    if existing_backup_count > 0:
        timestamp = datetime.now(UTC).strftime("%Y%m%d_%H%M%S")
        archived_name = f"{backup_collection}_{timestamp}"
        logger.warning(
            "기존 백업 컬렉션이 존재하여 %s 로 이름을 변경합니다. count=%d",
            archived_name,
            existing_backup_count,
        )
        await backup.rename(archived_name)
        backup = db[backup_collection]

    logger.info("백업 시작: %s -> %s", source_collection, backup_collection)
    await db.command(
        "aggregate",
        source_collection,
        pipeline=[{"$match": {}}, {"$out": backup_collection}],
        cursor={},
    )

    backup_count = await backup.count_documents({})
    logger.info("백업 완료: collection=%s, backup_count=%d", backup_collection, backup_count)
    return backup_count


async def rollback_from_backup(db, backup_collection: str, target_collection: str) -> None:
    """지정된 백업에서 대상 컬렉션으로 복원한다."""
    backup = db[backup_collection]
    target = db[target_collection]

    backup_count = await backup.count_documents({})
    if backup_count == 0:
        raise RuntimeError(f"롤백 실패: {backup_collection}이 비어 있습니다.")

    logger.warning("롤백 시작: %s -> %s", backup_collection, target_collection)
    await target.drop()
    await db.command(
        "aggregate",
        backup_collection,
        pipeline=[{"$match": {}}, {"$out": target_collection}],
        cursor={},
    )
    restored_count = await target.count_documents({})
    logger.warning("롤백 완료: collection=%s, restored_count=%d", target_collection, restored_count)


async def migrate_step1(db) -> None:
    """Step 1: food_ingredients의 필드를 우리 스키마로 변환한다."""
    source = db[FOOD_INGREDIENTS_COLLECTION]

    try:
        before_count = await source.count_documents({})
        logger.info("Step 1 시작: collection=%s, before_count=%d", FOOD_INGREDIENTS_COLLECTION, before_count)

        if before_count == 0:
            logger.warning("Step 1 중단: %s 컬렉션에 문서가 없습니다.", FOOD_INGREDIENTS_COLLECTION)
            return

        backup_count = await create_backup(db, FOOD_INGREDIENTS_COLLECTION, FOOD_INGREDIENTS_BACKUP)
        if backup_count != before_count:
            raise RuntimeError(
                f"백업 문서 수 불일치: before_count={before_count}, backup_count={backup_count}"
            )

        cursor = source.find({})
        transformed_documents: list[dict] = []

        async for document in cursor:
            transformed = transform_document(document)
            if not transformed["name"]:
                transformed["name"] = str(document.get("eng_name", "")).strip() or "UNKNOWN"
            transformed_documents.append(transformed)

        if not transformed_documents:
            raise RuntimeError("Step 1 변환 결과가 비어 있습니다.")

        await source.drop()
        insert_result = await source.insert_many(transformed_documents, ordered=False)

        after_count = await source.count_documents({})
        logger.info("Step 1 완료: inserted=%d, after_count=%d", len(insert_result.inserted_ids), after_count)

        sample_docs = await source.find({}, {"_id": 0}).limit(3).to_list(length=3)
        logger.info("Step 1 샘플 데이터(3개): %s", sample_docs)

    except Exception:
        logger.exception("Step 1 중 오류 발생")
        try:
            await rollback_from_backup(db, FOOD_INGREDIENTS_BACKUP, FOOD_INGREDIENTS_COLLECTION)
        except Exception:
            logger.exception("Step 1 자동 롤백 실패")
        raise


async def migrate_step2(db) -> None:
    """Step 2: ingredients 컬렉션을 food_ingredients로 통합한다."""
    food_ingredients = db[FOOD_INGREDIENTS_COLLECTION]
    ingredients = db[INGREDIENTS_COLLECTION]

    try:
        ingredients_before_count = await ingredients.count_documents({})
        food_ingredients_before_count = await food_ingredients.count_documents({})

        logger.info(
            "Step 2 시작: ingredients=%d, food_ingredients=%d",
            ingredients_before_count,
            food_ingredients_before_count,
        )

        if ingredients_before_count == 0:
            logger.warning("Step 2 중단: ingredients 컬렉션에 문서가 없습니다.")
            return

        # ingredients 백업 생성
        await create_backup(db, INGREDIENTS_COLLECTION, INGREDIENTS_BACKUP)

        # Step 2 이전 food_ingredients 백업 (롤백용)
        await create_backup(db, FOOD_INGREDIENTS_COLLECTION, FOOD_INGREDIENTS_BEFORE_STEP2)

        # ingredients 문서를 순회하며 food_ingredients에 통합
        cursor = ingredients.find({})
        merged_count = 0
        replaced_count = 0
        skipped_count = 0

        async for doc in cursor:
            transformed = transform_ingredients_document(doc)
            name = transformed["name"]

            if not name:
                skipped_count += 1
                continue

            # name 기준 기존 문서 확인
            existing = await food_ingredients.find_one({"name": name})
            if existing:
                await food_ingredients.delete_one({"name": name})
                replaced_count += 1
                logger.debug("문서 대체: name=%s", name)
            else:
                logger.debug("문서 추가: name=%s", name)

            # 새 문서 삽입
            await food_ingredients.insert_one(transformed)
            merged_count += 1

        final_count = await food_ingredients.count_documents({})
        logger.info(
            "Step 2 완료: merged=%d, replaced=%d, skipped=%d, final_count=%d",
            merged_count,
            replaced_count,
            skipped_count,
            final_count,
        )

        # 최종 샘플 출력 (5개)
        sample_docs = await food_ingredients.find({}, {"_id": 0}).limit(5).to_list(length=5)
        logger.info("Step 2 통합 샘플 데이터(5개): %s", sample_docs)

        logger.info("최종 상태: food_ingredients의 총 문서 수 = %d", final_count)

    except Exception:
        logger.exception("Step 2 중 오류 발생")
        try:
            await rollback_from_backup(db, FOOD_INGREDIENTS_BEFORE_STEP2, FOOD_INGREDIENTS_COLLECTION)
        except Exception:
            logger.exception("Step 2 자동 롤백 실패")
        raise


async def migrate(steps: list[str] = None) -> None:
    """마이그레이션을 지정된 단계로 실행한다."""
    if steps is None:
        steps = ["1", "2"]

    load_dotenv("backend/.env")
    load_dotenv()
    settings = Settings()

    client = AsyncIOMotorClient(settings.mongodb_uri)
    db = client[settings.mongodb_db_name]

    try:
        if "1" in steps:
            is_completed = await is_step1_completed(db)
            if is_completed:
                logger.info("Step 1은 이미 완료되었습니다. 스킵합니다.")
            else:
                logger.info("Step 1을 실행합니다.")
                await migrate_step1(db)

        if "2" in steps:
            logger.info("Step 2를 실행합니다.")
            await migrate_step2(db)

    finally:
        client.close()


if __name__ == "__main__":
    steps_to_run = ["1", "2"]  # 기본값: Step 1, Step 2 모두 실행

    # --step 옵션 파싱
    for arg in sys.argv[1:]:
        if arg.startswith("--step="):
            step_arg = arg.split("=")[1]
            steps_to_run = [step_arg]  # 특정 단계만 실행

    logger.info("실행 단계: %s", ", ".join([f"Step {s}" for s in steps_to_run]))
    asyncio.run(migrate(steps_to_run))
