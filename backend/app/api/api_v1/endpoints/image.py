"""
**Image Processing Endpoint**
Responsible for: Receiving image uploads and triggering soil texture classification.
Inputs/Outputs: Takes multipart file upload (field name: "file"), returns predicted
                soil texture (CNN model) and confidence score.
Dependencies: cnn_service.py

Route: POST /image/texture
Response envelope:
  Success:  { "success": true,  "data": { "soil_type": "...", "texture": "...", "confidence": 0.xx, "probs": {...} }, "error": null }
  Failure:  { "success": false, "data": null, "error": "<reason>" }
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
# Multipart field name must be "file" (matches Flutter's MultipartFile)

@router.post("/image/texture")
async def predict_texture(file: UploadFile = File(...)):
    try:
        contents: bytes = await file.read()

        if len(contents) < 512:
            return JSONResponse(status_code=400, content={
                "success": False,
                "data": None,
                "error": "Uploaded file is empty or too small. Please upload a valid soil image.",
            })

        result = predict_soil_type(contents)

        soil_type  = str(result["soil_type"])
        confidence = float(result["confidence"])
        probs      = {str(k): float(v) for k, v in result.get("probs", {}).items()}

        return JSONResponse(content={
            "success": True,
            "data": {
                "texture":    soil_type,   # legacy alias kept for backward compat
                "soil_type":  soil_type,   # primary field used by Flutter
                "confidence": confidence,
                "probs":      probs,
            },
            "error": None,
        })

    except RuntimeError as e:
        # Model unavailable / download failed / inference error — return clean 503
        err_msg = str(e)
        print(f"[image.py] RuntimeError: {err_msg}")
        return JSONResponse(status_code=503, content={
            "success": False,
            "data": None,
            "error": err_msg,
        })

    except Exception as e:
        print(f"[image.py] Unexpected error: {e}")
        traceback.print_exc()
        return JSONResponse(status_code=500, content={
            "success": False,
            "data": None,
            "error": "Internal server error during soil image analysis.",
        })
