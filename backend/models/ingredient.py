from pydantic import BaseModel, Field


class IngredientInfo(BaseModel):
    # 단일 성분 정보를 표현합니다.
    name: str = Field(..., description="성분명")
    description: str | None = Field(default=None, description="성분 설명")
    risk_level: str = Field(default="unknown", description="위험도(low|medium|high|unknown)")


class ScanRequest(BaseModel):
    # 제품명을 받아 성분 분석을 시작합니다.
    product_name: str = Field(..., min_length=1, description="분석할 제품명")


class ScanResponse(BaseModel):
    # 분석 결과 요약과 성분 목록을 반환합니다.
    product_name: str
    warning_ingredients: list[IngredientInfo] = []
    all_ingredients: list[IngredientInfo] = []
    warning_count: int = 0
    total_count: int = 0


class PreferencesRequest(BaseModel):
    # 사용자가 기피할 성분 목록을 저장합니다.
    user_id: str = Field(..., min_length=1, description="사용자 식별자")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")


class PreferencesResponse(BaseModel):
    # 저장 후 현재 설정 상태를 반환합니다.
    user_id: str
    avoided_ingredients: list[str]
