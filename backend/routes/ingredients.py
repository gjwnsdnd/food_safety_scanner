from fastapi import APIRouter, Query

from backend.services.db_service import get_db_service
from backend.services.ingredient_normalizer import normalize_ingredient_name

router = APIRouter(prefix="/api", tags=["ingredients"])


@router.get("/ingredients")
async def get_ingredients(category: str = Query(None)):
    db_service = get_db_service()
    if db_service.db is None:
        return {"ingredients": []}
    
    query = {}
    if category and category != "전체":
        query = {"categories": category}
        
    cursor = db_service.db["food_ingredients"].find(query, {"_id": 0, "name": 1})
    documents = await cursor.to_list(length=5000)

    normalized_names: set[str] = set()
    for document in documents:
        raw_name = document.get("name")
        if not isinstance(raw_name, str):
            continue
        normalized_name = normalize_ingredient_name(raw_name)
        if normalized_name:
            normalized_names.add(normalized_name)

    ingredients = sorted(normalized_names)  # 가나다순 정렬
    return {"ingredients": ingredients}


@router.get("/ingredients/detail")
async def get_ingredient_detail(name: str = Query(..., min_length=1)):
    db_service = get_db_service()
    if db_service.db is None:
        return {"detail": None}

    document = await db_service.db["food_ingredients"].find_one({"name": name}, {"_id": 0})
    if document is None:
        document = await db_service.db["food_ingredients"].find_one(
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
