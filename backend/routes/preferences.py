from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, HTTPException

from backend.models.ingredient import PreferencesRequest, PreferencesResponse, PreferencesGroup
from backend.services.db_service import get_db_service

router = APIRouter(prefix="/api", tags=["preferences"])


def _normalize_items(items: list[str]) -> list[str]:
    return sorted({item.strip() for item in items if item and item.strip()})


def _normalize_groups(raw_groups: list[dict] | None) -> list[PreferencesGroup]:
    groups: list[PreferencesGroup] = []
    if not raw_groups:
        return groups

    for group in raw_groups:
        name = str(group.get("group_name", "")).strip()
        if not name:
            continue

        ingredients = group.get("ingredients")
        if ingredients is None:
            ingredients = group.get("avoided_ingredients", [])

        groups.append(
            PreferencesGroup(
                group_name=name,
                ingredients=_normalize_items(list(ingredients) if isinstance(ingredients, list) else []),
            )
        )

    groups.sort(key=lambda g: g.group_name)
    return groups


@router.get("/preferences/{user_id}", response_model=PreferencesResponse)
async def get_preferences(user_id: str) -> PreferencesResponse:
    normalized_user_id = user_id.strip()
    if not normalized_user_id:
        raise HTTPException(status_code=400, detail="user_id는 필수입니다.")

    db_service = get_db_service()
    if db_service.db is None:
        raise HTTPException(status_code=500, detail="MongoDB 연결이 초기화되지 않았습니다.")

    try:
        document = await db_service.db["preferences"].find_one({"user_id": normalized_user_id})
    except Exception:
        raise HTTPException(status_code=500, detail="MongoDB 조회 중 오류가 발생했습니다.")

    if document is None:
        return PreferencesResponse(
            status="success",
            user_id=normalized_user_id,
            groups=[],
            avoided_ingredients=[],
            message="저장된 기피 성분이 없습니다.",
        )

    groups = _normalize_groups(document.get("groups"))
    avoided_ingredients = _normalize_items(document.get("avoided_ingredients", []))

    return PreferencesResponse(
        status="success",
        user_id=normalized_user_id,
        groups=groups,
        avoided_ingredients=avoided_ingredients,
        message="기피 성분 설정 조회에 성공했습니다.",
    )


@router.post("/preferences", response_model=PreferencesResponse)
async def save_preferences(payload: PreferencesRequest) -> PreferencesResponse:
    normalized_user_id = payload.user_id.strip()
    if not normalized_user_id:
        raise HTTPException(status_code=400, detail="user_id는 필수입니다.")

    db_service = get_db_service()
    if db_service.db is None:
        raise HTTPException(status_code=500, detail="MongoDB 연결이 초기화되지 않았습니다.")

    now = datetime.now(timezone.utc)
    normalized_ingredients = _normalize_items(payload.avoided_ingredients)
    normalized_groups = _normalize_groups(payload.groups)

    try:
        await db_service.db["preferences"].update_one(
            {"user_id": normalized_user_id},
            {
                "$set": {
                    "user_id": normalized_user_id,
                    "avoided_ingredients": normalized_ingredients,
                    "groups": [group.model_dump() for group in normalized_groups],
                    "updated_at": now,
                },
                "$setOnInsert": {
                    "created_at": now,
                },
            },
            upsert=True,
        )
    except Exception:
        raise HTTPException(status_code=500, detail="MongoDB 저장 중 오류가 발생했습니다.")

    return PreferencesResponse(
        status="success",
        user_id=normalized_user_id,
        groups=normalized_groups,
        avoided_ingredients=normalized_ingredients,
        message="기피 성분 설정이 저장되었습니다.",
    )
