"""
**Image Processing Endpoint**
Responsible for: Receiving image uploads and triggering soil texture classification.
Inputs/Outputs: Takes multipart file, returns predicted soil texture (CNN model) and confidence.
Dependencies: cnn_service.py.
"""

import traceback

from fastapi import APIRouter, File, HTTPException, UploadFile
from fastapi.responses import JSONResponse

from app.services.cnn_service import predict_soil_type

router = APIRouter()


# =====================================================
# IMAGE TEXTURE PREDICTION  (POST /image/texture)
# =====================================================
# Called by Flutter frontend via ApiService.analyzeSoilImage()
# Returns: { "success": true, "data": { "texture": "...", "confidence": 0.xx, ... }, "error": null }

@router.post("/image/texture")
async def predict_texture(file: UploadFile = File(...)):
    try:
        contents: bytes = await file.read()
        result = predict_soil_type(contents)

        soil_type  = str(result["soil_type"])
        confidence = float(result["confidence"])
        probs = {str(k): float(v) for k, v in result["probs"].items()}

        return JSONResponse(content={
            "success": True,
            "data": {
                "texture": soil_type,
                "soil_type": soil_type,
                "confidence": confidence,
                "probs": probs,
            },
            "error": None,
        })

    except RuntimeError as e:
        print(f"[image.py] RuntimeError: {e}")
        return JSONResponse(content={
            "success": True,
            "data": {
                "texture": "Unknown",
                "soil_type": "Unknown",
                "confidence": 0.0,
                "probs": {},
            },
            "error": str(e),
        })

    except Exception as e:
        print(f"[image.py] Unexpected error: {e}")
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=str(e))
