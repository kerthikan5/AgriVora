"""
**Crop LGBM Recommendation Endpoint**
Responsible for: Recommending crops using the pre-trained LightGBM predictive model.
Inputs/Outputs: Takes soil N, C, pH, rainfall, temperature, humidity, outputs ranked crop list.
Dependencies: crop_lgbm_service.py.
"""

from fastapi import APIRouter
from fastapi.responses import JSONResponse

from app.schemas.crop_lgbm_schema import CropLGBMRequest
from app.services.crop_lgbm_service import predict_crop

router = APIRouter(prefix="/crop", tags=["Crop Recommendation (LightGBM)"])


@router.post("/recommend")
def recommend(req: CropLGBMRequest):
    """
    Predict the best crop to grow using the LightGBM model.

    Returns a standardised envelope:
        {
          "success": true,
          "data": {
            "recommended_crop": "Rice",
            "confidence": 0.93,
            "recommendations": [
              {"crop": "Rice", "confidence": 0.93},
              {"crop": "Maize", "confidence": 0.72},
              ...
            ]
          },
          "error": null
        }
    """
    try:
        result = predict_crop(req.model_dump())

        # Build the standardised response expected by the Flutter frontend
        return JSONResponse(content={
            "success": True,
            "data": {
                "recommended_crop": result["crop"],
                "confidence": result["confidence"],
                "recommendations": result.get("recommendations", []),
            },
            "error": None,
        })

    except Exception as e:
        return JSONResponse(
            status_code=500,
            content={
                "success": False,
                "data": None,
                "error": str(e),
            },
        )