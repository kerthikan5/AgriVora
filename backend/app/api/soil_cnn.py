"""
**Soil CNN Legacy Router**
Provides direct access to CNN texture prediction.
"""

from fastapi import APIRouter, File, UploadFile

from app.services.cnn_service import predict_soil_type

router = APIRouter(prefix="/soil", tags=["Soil CNN"])


@router.post("/predict")
async def predict_soil(file: UploadFile = File(...)):
    """
    Direct CNN prediction endpoint.
    Returns: { "success": true, "data": { "soil_type": "...", "confidence": 0.xx, "probs": {...} } }
    """
    try:
        contents = await file.read()
        result = predict_soil_type(contents)  # predict_soil_type wraps bytes in BytesIO internally
        return {
            "success": True,
            "data": result,
            "error": None,
        }
    except Exception as e:
        return {
            "success": False,
            "data": None,
            "error": str(e),
        }