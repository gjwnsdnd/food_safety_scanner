import logging

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from backend.data.ingredient_details import INGREDIENT_DETAILS
from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["scan"])


class IngredientSearchResult(BaseModel):
    name: str = Field(..., description="성분명")
    eng_name: str = Field(..., description="영문명")
    classification: str = Field(..., description="분류")
    description: str = Field(default="", description="성분 설명")
    caution: str = Field(default="", description="주의사항")
    source: str = Field(..., description="데이터 출처")


class ScanSearchResponse(BaseModel):
    status: str = Field(default="success", description="응답 상태")
    product_name: str = Field(..., description="검색어")
    ingredients: list[IngredientSearchResult] = Field(default_factory=list, description="검색된 성분 목록")
    count: int = Field(..., ge=0, description="검색 결과 수")


def _normalize_name(text: str) -> str:
    return "".join(str(text).strip().lower().split())


DETAILS_BY_NORMALIZED_NAME = {
    _normalize_name(name): detail for name, detail in INGREDIENT_DETAILS.items()
}


def _find_detail_by_name(name: str) -> dict[str, str] | None:
    return DETAILS_BY_NORMALIZED_NAME.get(_normalize_name(name))


@router.post("/scan", response_model=ScanSearchResponse)
async def scan_ingredients(product_name: str = Query(..., min_length=1, description="검색할 성분명")) -> ScanSearchResponse:
    # 제품명으로 MongoDB의 food_ingredients 컬렉션을 검색합니다.
    search_term = product_name.strip()
    logger.info("Food ingredient search requested: product_name=%s", search_term)

    try:
        db_service = get_db_service()
        if not await db_service.check_connection():
            logger.error("MongoDB connection check failed for search: product_name=%s", search_term)
            raise HTTPException(status_code=500, detail="MongoDB 연결 상태를 확인할 수 없습니다.")

        query = {"name": {"$regex": search_term, "$options": "i"}}
        logger.info("MongoDB search query: %s", query)

        try:
            cursor = db_service.db["food_ingredients"].find(query, {"_id": 0}).limit(100)
            documents = await cursor.to_list(length=100)
        except Exception:
            logger.exception("MongoDB query failed: product_name=%s", search_term)
            raise HTTPException(status_code=500, detail="MongoDB 조회 중 오류가 발생했습니다.")

        ingredients = [
            IngredientSearchResult(
                name=str(document.get("name", "")),
                eng_name=(
                    str(document.get("eng_name", ""))
                    or ((_find_detail_by_name(str(document.get("name", ""))) or {}).get("eng_name", ""))
                ),
                classification=str(document.get("classification", "")),
                description=((_find_detail_by_name(str(document.get("name", ""))) or {}).get("description", "")),
                caution=((_find_detail_by_name(str(document.get("name", ""))) or {}).get("caution", "")),
                source=str(document.get("source", "")),
            )
            for document in documents
        ]

        count = len(ingredients)
        logger.info("Found ingredients count=%d for product_name=%s", count, search_term)

        return ScanSearchResponse(
            product_name=search_term,
            ingredients=ingredients,
            count=count,
        )
    except HTTPException:
        raise
    except Exception:
        logger.exception("Unexpected error during food ingredient search: product_name=%s", search_term)
        raise HTTPException(status_code=500, detail="성분 검색에 실패했습니다.")
