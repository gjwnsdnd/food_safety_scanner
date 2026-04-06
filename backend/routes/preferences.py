import logging
from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["preferences"])


class IngredientGroup(BaseModel):
    name: str = Field(..., description="그룹 이름")
    ingredients: list[str] = Field(default_factory=list, description="그룹에 속한 성분 목록")


class PreferencesRequest(BaseModel):
    user_id: str = Field(..., description="사용자 ID")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")
    groups: list[IngredientGroup] = Field(default_factory=list, description="저장된 그룹 목록")


class PreferencesResponse(BaseModel):
    user_id: str
    avoided_ingredients: list[str]
    groups: list[IngredientGroup]
    updated_at: str | None = None


@router.get("/preferences/{user_id}", response_model=PreferencesResponse)
async def get_preferences(user_id: str) -> PreferencesResponse:
    """저장된 기피 성분 및 그룹을 조회합니다."""
    logger.info("기피 성분 조회 요청: user_id=%s", user_id)
    try:
        db_service = get_db_service()
        doc = await db_service.db["preferences"].find_one(
            {"user_id": user_id},
            {"_id": 0},
        )
        if doc is None:
            return PreferencesResponse(
                user_id=user_id,
                avoided_ingredients=[],
                groups=[],
            )
        return PreferencesResponse(
            user_id=doc["user_id"],
            avoided_ingredients=doc.get("avoided_ingredients", []),
            groups=[
                IngredientGroup(
                    name=g["name"],
                    ingredients=g.get("ingredients", []),
                )
                for g in doc.get("groups", [])
            ],
            updated_at=doc.get("updated_at"),
        )
    except Exception:
        logger.exception("기피 성분 조회 오류: user_id=%s", user_id)
        raise HTTPException(status_code=500, detail="기피 성분 조회에 실패했습니다.")


@router.post("/preferences", response_model=PreferencesResponse)
async def save_preferences(req: PreferencesRequest) -> PreferencesResponse:
    """기피 성분 및 그룹을 저장합니다."""
    logger.info(
        "기피 성분 저장 요청: user_id=%s, count=%d",
        req.user_id,
        len(req.avoided_ingredients),
    )
    try:
        db_service = get_db_service()
        now = datetime.now(tz=timezone.utc).isoformat()
        document = {
            "user_id": req.user_id,
            "avoided_ingredients": req.avoided_ingredients,
            "groups": [g.model_dump() for g in req.groups],
            "updated_at": now,
        }
        await db_service.db["preferences"].update_one(
            {"user_id": req.user_id},
            {"$set": document},
            upsert=True,
        )
        return PreferencesResponse(
            user_id=req.user_id,
            avoided_ingredients=req.avoided_ingredients,
            groups=req.groups,
            updated_at=now,
        )
    except Exception:
        logger.exception("기피 성분 저장 오류: user_id=%s", req.user_id)
        raise HTTPException(status_code=500, detail="기피 성분 저장에 실패했습니다.")
