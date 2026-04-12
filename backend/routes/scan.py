import logging

from fastapi import APIRouter, File, HTTPException, Query, UploadFile
from pydantic import BaseModel, Field

from backend.services.db_service import get_db_service
from backend.services.ocr_service import extract_text_from_image, preprocess_image, search_ingredients

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


class OcrOnlyResponse(BaseModel):
    status: str = Field(default="success", description="응답 상태")
    file_name: str = Field(default="", description="업로드 파일명")
    extracted_text: str = Field(default="", description="OCR 추출 텍스트")
    ingredients: list[dict] = Field(default_factory=list, description="검색된 성분 목록")
    ingredient_count: int = Field(default=0, ge=0, description="검색된 성분 개수")


async def _find_detail_by_name(db_service, ingredient_name: str) -> dict[str, str] | None:
    # MongoDB의 ingredients 컬렉션에서 성분 상세정보를 조회합니다.
    try:
        detail = await db_service.db["ingredients"].find_one(
            {"name": ingredient_name},
            {"_id": 0, "name": 0},
        )
        return detail
    except Exception:
        logger.exception("Failed to fetch ingredient detail: ingredient_name=%s", ingredient_name)
        return None


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

        ingredients = []
        for document in documents:
            ingredient_name = str(document.get("name", ""))
            detail = await _find_detail_by_name(db_service, ingredient_name)
            if detail is None:
                detail = {}

            ingredients.append(
                IngredientSearchResult(
                    name=ingredient_name,
                    eng_name=str(document.get("eng_name", "")),
                    classification=str(document.get("classification", "")),
                    description=detail.get("description", ""),
                    caution=detail.get("caution", ""),
                    source=str(document.get("source", "")),
                )
            )

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


@router.post("/scan/ocr", response_model=OcrOnlyResponse)
async def scan_ocr_only(file: UploadFile = File(...)) -> OcrOnlyResponse:
    print(f"[OCR HIT] file={file.filename}, content_type={file.content_type}", flush=True)

    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")

    try:
        content = await file.read()

        preprocess_image(content)
        logger.info("[OCR PREPROCESS] completed: file_name=%s", file.filename or "")

        extracted_text = extract_text_from_image(content)
        print(f"[OCR TEXT PREVIEW] {extracted_text[:200]}", flush=True)
        logger.info("OCR extracted text (%s):\n%s", file.filename or "", extracted_text)

        # search_ingredients() 호출 및 에러 처리
        ingredients = await search_ingredients(extracted_text)
        
        # ingredients가 None인 경우 처리
        if ingredients is None:
            logger.warning("[OCR SEARCH] ingredients is None, treating as empty list")
            ingredients = []
        
        # ingredients가 리스트인지 확인
        if not isinstance(ingredients, list):
            logger.error("[OCR SEARCH] ingredients is not a list, type=%s", type(ingredients))
            ingredients = []
        
        # 빈 리스트인지 확인
        if not ingredients:
            logger.warning("[OCR SEARCH] no ingredients found")
        
        # 개선된 로그: len 안전 처리
        ingredient_count = len(ingredients) if ingredients else 0
        logger.info(
            "[OCR SEARCH] completed: file_name=%s, ingredient_count=%d",
            file.filename or "",
            ingredient_count,
        )
        
        # 반환된 각 성분의 name 필드 로그 출력 (대두 등의 포함 여부 확인)
        if ingredients:
            ingredient_names = [str(item.get("name", "")) for item in ingredients[:10]]  # 상위 10개만
            logger.info("[OCR SEARCH] 디버깅: 반환된 성분 수 = %d", len(ingredients))
            logger.info("[OCR SEARCH] 반환된 성분명 (상위 10개): %s", ingredient_names)
            if ingredients:
                logger.info("[OCR SEARCH] 첫 번째 성분명: %s", ingredients[0].get("name", ""))
        else:
            logger.info("[OCR SEARCH] 디버깅: 반환된 성분 수 = 0 (검색 결과 없음)")

        return OcrOnlyResponse(
            status="success",
            file_name=file.filename or "",
            extracted_text=extracted_text,
            ingredients=ingredients,
            ingredient_count=ingredient_count,
        )
    except HTTPException:
        raise
    except Exception as exc:
        logger.exception("OCR failed: file_name=%s", file.filename)
        raise HTTPException(status_code=500, detail=str(exc) or "OCR 처리 중 오류가 발생했습니다.")
