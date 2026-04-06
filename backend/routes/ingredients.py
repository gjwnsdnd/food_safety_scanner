from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["ingredients"])


@router.get("/ingredients")
async def get_ingredients():
    return {"ingredients": []}