import logging

from collections import OrderedDict

from fastapi import APIRouter, HTTPException

from backend.models.ingredient import Ingredient, ScanRequest, ScanResponse
from backend.services.db_service import get_db_service

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["scan"])


def _extract_candidate_names(product_name: str) -> list[str]:
    # 제품명 문자열에서 성분 후보명을 추출합니다..
    normalized = (
        product_name.replace("\n", ",")
        .replace("/", ",")
        .replace(";", ",")
        .replace("|", ",")
        .replace("·", ",")
    )
    tokens = [token.strip() for token in normalized.split(",") if token.strip()]
    # 중복 제거 + 순서 유지
    return list(OrderedDict.fromkeys(tokens))


def _normalize_risk_level(value: str | None) -> str:
    if value in {"safe", "caution", "danger"}:
        return value
    return "caution"


@router.post("/scan", response_model=ScanResponse)
async def scan_ingredients(payload: ScanRequest) -> ScanResponse:
    # 제품명을 받아 성분 분석 결과를 반환합니다.
    logger.info(
        "Scan requested: product_name=%s avoided_count=%d",
        payload.product_name,
        len(payload.avoided_ingredients),
    )

    try:
        db_service = get_db_service()
        avoided_set = {item.strip().lower() for item in payload.avoided_ingredients if item.strip()}

        candidates = _extract_candidate_names(payload.product_name)
        if payload.product_name.strip() and payload.product_name.strip() not in candidates:
            candidates.insert(0, payload.product_name.strip())

        ingredient_docs_by_name: OrderedDict[str, dict] = OrderedDict()
        for candidate in candidates:
            doc = await db_service.get_ingredient(candidate)
            if doc is None:
                continue
            key = str(doc.get("name", candidate)).strip().lower()
            ingredient_docs_by_name[key] = doc

        # 제품을 찾지 못한 경우(또는 매칭 성분 없음) 빈 리스트 반환
        if not ingredient_docs_by_name:
            logger.info("No ingredients found for product_name=%s", payload.product_name)
            return ScanResponse(
                product_name=payload.product_name,
                ingredients=[],
                warning_count=0,
                risk_level="safe",
            )

        ingredients: list[Ingredient] = []
        warning_count = 0
        has_danger = False

        for doc in ingredient_docs_by_name.values():
            name = str(doc.get("name", "")).strip() or "Unknown"
            risk_level = _normalize_risk_level(doc.get("risk_level"))
            description = str(doc.get("description", "설명 정보가 없습니다.")).strip() or "설명 정보가 없습니다."
            alternatives = [str(item) for item in doc.get("alternatives", []) if str(item).strip()]

            # 사용자가 기피한 성분이면 최소 caution으로 처리합니다.
            if name.lower() in avoided_set and risk_level == "safe":
                risk_level = "caution"
                description = f"{description} (사용자 기피 성분)"

            if risk_level in {"caution", "danger"}:
                warning_count += 1
            if risk_level == "danger":
                has_danger = True

            ingredients.append(
                Ingredient(
                    name=name,
                    risk_level=risk_level,
                    description=description,
                    alternatives=alternatives,
                )
            )

        overall_risk_level = "danger" if has_danger else ("caution" if warning_count > 0 else "safe")

        response = ScanResponse(
            product_name=payload.product_name,
            ingredients=ingredients,
            warning_count=warning_count,
            risk_level=overall_risk_level,
        )

        logger.info(
            "Scan completed: product_name=%s ingredients=%d warnings=%d risk=%s",
            payload.product_name,
            len(ingredients),
            warning_count,
            overall_risk_level,
        )
        return response
    except RuntimeError as exc:
        logger.exception("Database error during scan: product_name=%s", payload.product_name)
        raise HTTPException(status_code=500, detail="DB 조회 중 오류가 발생했습니다.") from exc
    except Exception as exc:
        logger.exception("Failed to analyze product: %s", payload.product_name)
        raise HTTPException(status_code=500, detail="성분 분석에 실패했습니다.") from exc
