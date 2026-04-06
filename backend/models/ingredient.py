from pydantic import BaseModel, Field


class Ingredient(BaseModel):
    # 성분 이름
    name: str = Field(..., min_length=1, description="성분 이름", examples=["Paraben"])
    # 성분 설명
    description: str = Field(default="", description="설명")
    # 주의사항
    caution: str = Field(default="", description="주의사항")




class PreferencesRequest(BaseModel):
    # 사용자가 기피할 성분 목록을 저장합니다.
    user_id: str = Field(..., min_length=1, description="사용자 식별자")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")


class PreferencesResponse(BaseModel):
    # 저장 후 현재 설정 상태를 반환합니다.
    user_id: str
    avoided_ingredients: list[str]
