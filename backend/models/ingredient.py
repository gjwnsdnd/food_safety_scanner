from pydantic import BaseModel, Field


class Ingredient(BaseModel):
    name: str = Field(..., min_length=1, description="성분 이름")
    description: str = Field(default="", description="설명")
    caution: str = Field(default="", description="주의사항")
    categories: list[str] = Field(default_factory=list, description="카테고리")


class PreferencesGroup(BaseModel):
    group_name: str = Field(..., min_length=1, description="그룹 이름")
    ingredients: list[str] = Field(default_factory=list, description="그룹 성분 목록")


class PreferencesRequest(BaseModel):
    user_id: str = Field(..., min_length=1, description="사용자 식별자")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")
    groups: list[dict] = Field(default_factory=list, description="저장된 그룹 목록")


class PreferencesResponse(BaseModel):
    status: str = Field(default="success", description="응답 상태")
    user_id: str
    groups: list[PreferencesGroup] = Field(default_factory=list, description="저장된 그룹")
    avoided_ingredients: list[str] = Field(default_factory=list, description="현재 선택된 기피 성분 목록")
    message: str = Field(default="", description="응답 메시지")
