"""
**Recommend Endpoint**
Responsible for: Providing crop recommendations using standard logic/models (RandomForest or basic metrics).
"""

from datetime import datetime
from typing import Any, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, model_validator

from app.services.recommend_service import recommend_crops
# from app.utils.firestore import save_scan_history

router = APIRouter()


# =====================================================
# REQUEST SCHEMA — accepts both camelCase and snake_case
# =====================================================

class RecommendRequest(BaseModel):
    userId: Optional[str] = None
    soilType: Optional[str] = None
    ph: float
    temperature: float
    rainfall: float
    humidity: float

    @model_validator(mode="before")
    @classmethod
    def normalize_fields(cls, values: Any) -> Any:
        """Allow both snake_case (frontend) and camelCase (legacy) field names."""
        if isinstance(values, dict):
            # snake_case → camelCase normalization
            if "user_id" in values and "userId" not in values:
                values["userId"] = values.pop("user_id")
            if "soil_type" in values and "soilType" not in values:
                values["soilType"] = values.pop("soil_type")
        return values


# =====================================================
# MANUAL SOIL RECOMMENDATION
# =====================================================

@router.post("/recommend")
def recommend(data: RecommendRequest):

    if not (0 <= data.ph <= 14):
        raise HTTPException(
            status_code=400,
            detail="Invalid pH value"
        )

    # Convert soilType to numeric values (example mapping)
    soil_map = {
        "Sandy": {"sand": 70, "clay": 10, "organicCarbon": 0.5},
        "Clay": {"sand": 20, "clay": 60, "organicCarbon": 1.5},
        "Loamy": {"sand": 40, "clay": 30, "organicCarbon": 1.2}
    }

    soil_type = data.soilType or "Loamy"
    soil_summary = soil_map.get(soil_type)

    if soil_summary is None:
        raise HTTPException(status_code=400, detail=f"Invalid soil type '{soil_type}'. Must be one of: Sandy, Clay, Loamy")

    weather_summary = {
        "temperature": data.temperature,
        "rainfall": data.rainfall,
        "humidity": data.humidity
    }

    # ML Prediction
    results, error = recommend_crops({
        "soil": soil_summary,
        "weather": weather_summary,
        "ph": data.ph
    })

    if error or results is None:
        raise HTTPException(
            status_code=500,
            detail="Recommendation failed"
        )

    # Save to Firestore (only if user is logged in)
    # if data.userId:
    #     save_scan_history({
    #         "userId": data.userId,
    #         "soilSummary": soil_summary,
    #         "weatherSummary": weather_summary,
    #         "ph": data.ph,
    #         "results": results,
    #         "createdAt": datetime.utcnow()
    #     })

    return {
        "success": True,
        "data": {
            "crops": results
        },
        "error": None
    }
