import logging

from fastapi import APIRouter, HTTPException

from backend.models.ingredient import IngredientDetail, PreferencesRequest, PreferencesResponse
from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["ingredients", "preferences"])


@router.get("/ingredients/{name}", response_model=IngredientDetail)
async def get_ingredient(name: str) -> IngredientDetail:
    # 성분명을 기준으로 DB에서 상세 정보를 조회합니다.
    db_service = get_db_service()
    doc = await db_service.get_ingredient_by_name(name)

    if doc is None:
        raise HTTPException(status_code=404, detail="해당 성분 정보를 찾을 수 없습니다.")

    raw_risk_level = doc.get("risk_level", "safe")
    if raw_risk_level not in {"safe", "caution", "danger"}:
        raw_risk_level = "caution"

    return IngredientDetail(
        name=doc.get("name", name),
        description=doc.get("description", "설명 정보가 없습니다."),
        risk_level=raw_risk_level,
        alternatives=doc.get("alternatives", []),
    )


@router.post("/preferences", response_model=PreferencesResponse)
async def save_preferences(payload: PreferencesRequest) -> PreferencesResponse:
    # 사용자 기피 성분 목록을 저장/갱신합니다.
    db_service = get_db_service()

    # 중복/공백을 제거해 저장 품질을 보장합니다.
    normalized = sorted({item.strip() for item in payload.avoided_ingredients if item.strip()})

    await db_service.save_user_preferences(
        user_id=payload.user_id,
        avoided_ingredients=normalized,
    )

    logger.info("Updated preferences for user_id=%s (count=%d)", payload.user_id, len(normalized))

    return PreferencesResponse(
        user_id=payload.user_id,
        avoided_ingredients=normalized,
    )
