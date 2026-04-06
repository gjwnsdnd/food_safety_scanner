from pydantic import BaseModel, Field


class Ingredient(BaseModel):
    name: str = Field(..., min_length=1, description="성분 이름")
    description: str = Field(default="", description="설명")
    caution: str = Field(default="", description="주의사항")
    categories: list[str] = Field(default_factory=list, description="카테고리")


class AvoidanceGroup(BaseModel):
    group_name: str = Field(..., min_length=1, description="그룹 이름")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")
    categories: list[str] = Field(default_factory=list, description="카테고리 목록")


class PreferencesRequest(BaseModel):
    user_id: str = Field(..., min_length=1, description="사용자 식별자")
    group_name: str = Field(..., min_length=1, description="그룹 이름")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")


class PreferencesResponse(BaseModel):
    user_id: str
    groups: list[AvoidanceGroup] = Field(default_factory=list, description="저장된 그룹")
