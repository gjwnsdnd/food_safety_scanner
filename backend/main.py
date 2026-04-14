import logging
import os
from contextlib import asynccontextmanager

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic_settings import BaseSettings, SettingsConfigDict

from backend.routes.ingredients import router as ingredients_router
from backend.routes.preferences import router as preferences_router
from backend.routes.scan import router as scan_router
from backend.app.api.routes.admin import router as admin_router
from backend.services.db_service import get_db_service, init_db_service

 
class Settings(BaseSettings):
    # .env 기반 애플리케이션 설정입니다.
    app_name: str = "Food Safety Scanner API"
    app_env: str = "development"
    app_host: str = "0.0.0.0"
    app_port: int = 8000
    cors_origins: str = "http://localhost:3000,http://127.0.0.1:3000"
    mongodb_uri: str = "mongodb://localhost:27017"
    mongodb_db_name: str = "food_safety"
    google_application_credentials: str | None = None

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    @property
    def parsed_cors_origins(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]


# 앱 시작 전에 backend/.env를 우선 로딩합니다.
load_dotenv("backend/.env")
load_dotenv()
settings = Settings()

if settings.google_application_credentials:
    os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = settings.google_application_credentials

# 서비스 전반에서 공통으로 사용할 로깅 포맷입니다.
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(name)s | %(message)s",
)
logger = logging.getLogger(__name__)

# DB 서비스 싱글턴을 앱 초기화 시점에 준비합니다.
init_db_service(uri=settings.mongodb_uri, db_name=settings.mongodb_db_name)


@asynccontextmanager
async def lifespan(app: FastAPI):
    # startup
    try:
        await get_db_service().connect()
    except Exception:
        logger.exception("MongoDB connection failed on startup")

    yield 

    # shutdown
    try:
        await get_db_service().disconnect()
    except Exception:
        logger.exception("MongoDB disconnect failed on shutdown")


app = FastAPI(title=settings.app_name, lifespan=lifespan)

# Flutter/Web 클라이언트 호출을 허용하기 위한 CORS 설정입니다.
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.parsed_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 라우터 등록
app.include_router(scan_router)
app.include_router(ingredients_router)
app.include_router(preferences_router)
app.include_router(admin_router)


@app.get("/health")
async def health_check() -> dict[str, str]:
    # 서버 상태 확인용 엔드포인트입니다.
    return {"status": "ok", "env": settings.app_env}


@app.exception_handler(RequestValidationError)
async def validation_exception_handler(request: Request, exc: RequestValidationError):
    # 요청 바디/파라미터 유효성 실패를 일관된 포맷으로 반환합니다.
    logger.warning("Validation failed for %s: %s", request.url.path, exc.errors())
    return JSONResponse(
        status_code=422,
        content={
            "message": "요청 형식이 올바르지 않습니다.",
            "errors": exc.errors(),
        },
    )


@app.exception_handler(HTTPException)
async def http_exception_handler(request: Request, exc: HTTPException):
    # 예상 가능한 HTTP 예외를 로깅 후 그대로 전달합니다.
    logger.warning("HTTP error on %s: %s", request.url.path, exc.detail)
    return JSONResponse(status_code=exc.status_code, content={"message": exc.detail})


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    # 처리되지 않은 예외를 잡아 500으로 응답합니다.
    logger.exception("Unhandled error on %s", request.url.path)
    return JSONResponse(
        status_code=500,
        content={"message": "서버 내부 오류가 발생했습니다."},
    )
