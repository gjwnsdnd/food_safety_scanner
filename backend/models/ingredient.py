from typing import Literal

from pydantic import BaseModel, Field


class Ingredient(BaseModel):
    # 성분 이름
    name: str = Field(..., min_length=1, description="성분 이름", examples=["Paraben"])
    # 위험도(safe/caution/danger)
    risk_level: Literal["safe", "caution", "danger"] = Field(
        ...,
        description="위험도",
        examples=["caution"],
    )
    # 성분 설명
    description: str = Field(..., min_length=1, description="설명", examples=["피부 자극 가능성이 있습니다."])
    # 대체 가능한 성분 목록(선택)
    alternatives: list[str] = Field(
        default_factory=list,
        description="대체 성분 목록",
        examples=[["Aloe Vera Extract", "Chamomile Extract"]],
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "Paraben",
                "risk_level": "caution",
                "description": "피부 자극 가능성이 있습니다.",
                "alternatives": ["Aloe Vera Extract", "Chamomile Extract"],
            }
        }
    }


class ScanRequest(BaseModel):
    # 분석할 제품명
    product_name: str = Field(..., min_length=1, description="제품명", examples=["Moisture Cream"])
    # 기피 성분 목록(선택)
    avoided_ingredients: list[str] = Field(
        default_factory=list,
        description="기피 성분 목록",
        examples=[["Paraben", "SLS"]],
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "product_name": "Moisture Cream",
                "avoided_ingredients": ["Paraben", "SLS"],
            }
        }
    }


class ScanResponse(BaseModel):
    # 제품명
    product_name: str = Field(..., description="제품명", examples=["Moisture Cream"])
    # 성분 리스트
    ingredients: list[Ingredient] = Field(default_factory=list, description="성분 리스트")
    # 위험 성분 개수
    warning_count: int = Field(..., ge=0, description="위험한 성분 개수", examples=[1])
    # 전체 위험도
    risk_level: Literal["safe", "caution", "danger"] = Field(
        ...,
        description="전체 위험도",
        examples=["caution"],
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "product_name": "Moisture Cream",
                "ingredients": [
                    {
                        "name": "Paraben",
                        "risk_level": "caution",
                        "description": "피부 자극 가능성이 있습니다.",
                        "alternatives": ["Aloe Vera Extract", "Chamomile Extract"],
                    }
                ],
                "warning_count": 1,
                "risk_level": "caution",
            }
        }
    }


class IngredientDetail(Ingredient):
    # Ingredient의 모든 필드를 포함하는 상세 응답 모델
    model_config = {
        "json_schema_extra": {
            "example": {
                "name": "Paraben",
                "risk_level": "caution",
                "description": "피부 자극 가능성이 있습니다.",
                "alternatives": ["Aloe Vera Extract", "Chamomile Extract"],
            }
        }
    }


# Backward compatibility for existing imports.
IngredientInfo = Ingredient


class PreferencesRequest(BaseModel):
    # 사용자가 기피할 성분 목록을 저장합니다.
    user_id: str = Field(..., min_length=1, description="사용자 식별자")
    avoided_ingredients: list[str] = Field(default_factory=list, description="기피 성분 목록")


class PreferencesResponse(BaseModel):
    # 저장 후 현재 설정 상태를 반환합니다.
    user_id: str
    avoided_ingredients: list[str]
