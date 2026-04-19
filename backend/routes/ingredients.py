from fastapi import APIRouter, Query

from backend.services.db_service import get_db_service

router = APIRouter(prefix="/api", tags=["ingredients"])


@router.get("/ingredients")
async def get_ingredients():
    return {"ingredients": []}


@router.get("/ingredients/detail")
async def get_ingredient_detail(name: str = Query(..., min_length=1)):
    db_service = get_db_service()
    if db_service.db is None:
        return {"detail": None}

    document = await db_service.db["ingredients"].find_one({"name": name}, {"_id": 0})
    if document is None:
        document = await db_service.db["ingredients"].find_one(
            {"name": {"$regex": name, "$options": "i"}},
            {"_id": 0},
        )

    if document is None:
        return {"detail": None}

    normalized = dict(document)
    if "uses" not in normalized or not str(normalized.get("uses", "")).strip():
        for key in ("useCondition", "use_condition", "use_condition_kor", "usecondition"):
            value = str(normalized.get(key, "")).strip()
            if value:
                normalized["uses"] = value
                break

    return {"detail": normalized}