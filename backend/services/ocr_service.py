import logging

from backend.models.ingredient import IngredientInfo, ScanResponse

logger = logging.getLogger(__name__)


class OCRService:
    # Google Vision OCR 연동 지점을 담당합니다.
    async def analyze_product(
        self,
        product_name: str,
        avoided_ingredients: list[str] | None = None,
    ) -> ScanResponse:
        # 현재는 연동 전 기본 골격만 반환하고, 추후 OCR/LLM 파이프라인을 연결합니다.
        logger.info("Analyze requested for product: %s", product_name)

        # TODO: Google Vision OCR -> 텍스트 추출 -> 성분 파싱 -> DB 매칭 구현
        ingredients: list[IngredientInfo] = []

        # 기피 성분이 요청에 포함되더라도 현재 스텁에서는 구조만 전달합니다.
        _ = avoided_ingredients or []

        return ScanResponse(
            product_name=product_name,
            ingredients=ingredients,
            warning_count=0,
            risk_level="safe",
        )


ocr_service = OCRService()
