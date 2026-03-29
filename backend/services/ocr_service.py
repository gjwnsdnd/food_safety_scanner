import logging

from backend.models.ingredient import IngredientInfo, ScanResponse

logger = logging.getLogger(__name__)


class OCRService:
    # Google Vision OCR 연동 지점을 담당합니다.
    async def analyze_product(self, product_name: str) -> ScanResponse:
        # 현재는 연동 전 기본 골격만 반환하고, 추후 OCR/LLM 파이프라인을 연결합니다.
        logger.info("Analyze requested for product: %s", product_name)

        # TODO: Google Vision OCR -> 텍스트 추출 -> 성분 파싱 -> DB 매칭 구현
        all_ingredients: list[IngredientInfo] = []
        warning_ingredients: list[IngredientInfo] = []

        return ScanResponse(
            product_name=product_name,
            all_ingredients=all_ingredients,
            warning_ingredients=warning_ingredients,
            warning_count=len(warning_ingredients),
            total_count=len(all_ingredients),
        )


ocr_service = OCRService()
