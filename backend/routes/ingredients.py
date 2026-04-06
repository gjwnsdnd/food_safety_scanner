from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["ingredients"])


@router.get("/ingredients")
async def get_ingredients_health() -> dict[str, str]:
    # 기본 라우터 존재 여부 확인용 엔드포인트입니다.
    return {"status": "success", "message": "ingredients router ready"}
