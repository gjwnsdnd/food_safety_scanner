import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from backend.services.image_quality import evaluate_image_quality

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api", tags=["scan"])


@router.post("/scan/quality")
async def scan_image_quality(file: UploadFile = File(...)) -> dict:
    if not file.content_type or not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="이미지 파일만 업로드할 수 있습니다.")

    try:
        content = await file.read()
        result = evaluate_image_quality(content)
        logger.info(
            "Image quality checked: file_name=%s warning=%s reasons=%s",
            file.filename or "",
            result.warning,
            result.reasons,
        )
        return result.to_dict()
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc))
    except HTTPException:
        raise
    except Exception:
        logger.exception("Image quality check failed: file_name=%s", file.filename or "")
        raise HTTPException(status_code=500, detail="이미지 품질 분석 중 오류가 발생했습니다.")
