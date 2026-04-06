from fastapi import APIRouter

router = APIRouter(prefix="/api", tags=["admin"])

@router.get("/admin/health")
async def admin_health():
    return {"status": "ok"}