import logging

from fastapi import APIRouter

from backend.models.ingredient import PreferencesRequest, PreferencesResponse
from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api")

@router.post("/preferences", response_model=PreferencesResponse, tags=["preferences"])
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
