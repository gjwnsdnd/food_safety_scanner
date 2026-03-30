import logging

from fastapi import APIRouter, HTTPException

from backend.models.ingredient import ScanRequest, ScanResponse
from backend.services.ocr_service import ocr_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["scan"])


@router.post("/scan", response_model=ScanResponse)
async def scan_ingredients(payload: ScanRequest) -> ScanResponse:
    # 제품명을 받아 성분 분석 결과를 반환합니다.
    try:
        return await ocr_service.analyze_product(
            payload.product_name,
            payload.avoided_ingredients,
        )
    except Exception as exc:
        logger.exception("Failed to analyze product: %s", payload.product_name)
        raise HTTPException(status_code=500, detail="성분 분석에 실패했습니다.") from exc
