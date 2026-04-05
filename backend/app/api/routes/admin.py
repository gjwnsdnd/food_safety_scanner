import logging
from collections.abc import Iterable

import httpx
from fastapi import APIRouter, HTTPException, Query
from pymongo.errors import PyMongoError

from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/admin", tags=["admin"])

API_KEY = "fead84646d5e4b4cb8fe"
FOOD_INGREDIENTS_COLLECTION = "food_ingredients"
I1020_URL = "http://openapi.foodsafetykorea.go.kr/api/{keyId}/I1020/json/1/{endIdx}"
I0950_URL = "http://openapi.foodsafetykorea.go.kr/api/{keyId}/I0950/json/1/{endIdx}"


def _extract_field(row: dict, candidates: Iterable[str], default: str = "") -> str:
    for candidate in candidates:
        value = row.get(candidate)
        if value is None:
            continue
        text = str(value).strip()
        if text:
            return text
    return default


def _normalize_risk_level(row: dict, source: str) -> str:
    raw_risk = _extract_field(row, ["risk_level", "RISK_LEVEL", "RISK", "GRADE"])
    if raw_risk in {"safe", "caution", "danger"}:
        return raw_risk

    if source == "I0950":
        return "caution"
    return "safe"


def _extract_rows(payload: dict, dataset_key: str) -> list[dict]:
    dataset = payload.get(dataset_key, {})
    if not isinstance(dataset, dict):
        return []

    rows = dataset.get("row", [])
    if isinstance(rows, list):
        return [row for row in rows if isinstance(row, dict)]
    return []


async def _fetch_api_rows(client: httpx.AsyncClient, url: str, key_id: str, end_idx: int, dataset_key: str) -> list[dict]:
    response = await client.get(url.format(keyId=key_id, endIdx=end_idx))
    response.raise_for_status()

    payload = response.json()
    rows = _extract_rows(payload, dataset_key)
    logger.info("Fetched %s rows from %s", len(rows), dataset_key)
    return rows


@router.post("/sync-food-data")
async def sync_food_data(end_idx: int = Query(default=100, ge=1, description="조회할 마지막 인덱스")):
    logger.info("Food data sync started: end_idx=%d", end_idx)

    db_service = get_db_service()
    if not await db_service.check_connection():
        logger.error("MongoDB connection is not healthy")
        raise HTTPException(status_code=500, detail="MongoDB 연결 상태를 확인할 수 없습니다.")

    saved_count = 0
    timeout = httpx.Timeout(30.0)

    try:
        async with httpx.AsyncClient(timeout=timeout) as client:
            api_jobs = [
                ("I1020", I1020_URL, ["I1020"]),
                ("I0950", I0950_URL, ["I0950"]),
            ]

            for source, url, dataset_candidates in api_jobs:
                rows = []
                for dataset_key in dataset_candidates:
                    try:
                        rows = await _fetch_api_rows(client, url, API_KEY, end_idx, dataset_key)
                        if rows:
                            break
                    except httpx.HTTPError:
                        logger.exception("Failed to fetch food API rows: source=%s", source)
                        raise HTTPException(status_code=502, detail=f"{source} 공공 API 호출에 실패했습니다.")

                for row in rows:
                    name = _extract_field(row, ["name", "NAME", "NUTR_CONT1", "PRDLST_NM", "FOOD_NM", "ADDITIVE_NM"])
                    if not name:
                        continue

                    ingredient_data = {
                        "name": name,
                        "eng_name": _extract_field(row, ["eng_name", "ENG_NAME", "PRDLST_NM_ENG", "FOOD_NM_ENG", "ADDITIVE_NM_ENG"]),
                        "classification": _extract_field(row, ["classification", "CLASSIFICATION", "PRDLST_CTGRY_NM", "CLASS_NM", "TYPE_NM"]),
                        "risk_level": _normalize_risk_level(row, source),
                        "source": source,
                    }

                    try:
                        await db_service.db[FOOD_INGREDIENTS_COLLECTION].update_one(
                            {"name": name},
                            {"$set": ingredient_data},
                            upsert=True,
                        )
                        saved_count += 1
                    except ValueError:
                        logger.warning("Skipping invalid ingredient payload from %s: %s", source, row)
                    except PyMongoError:
                        logger.exception("Failed to save ingredient from %s: %s", source, name)
                        raise HTTPException(status_code=500, detail="MongoDB 저장 중 오류가 발생했습니다.")

        message = f"식품원재료/첨가물 데이터를 MongoDB에 동기화했습니다."
        logger.info("Food data sync completed: saved_count=%d", saved_count)
        return {"status": "success", "message": message, "count": saved_count}
    except HTTPException:
        raise
    except Exception:
        logger.exception("Unexpected error during food data sync")
        raise HTTPException(status_code=500, detail="식품 데이터 동기화에 실패했습니다.")
