"""
**Recommend Service**
Responsible for: Providing crop recommendations for the /recommend endpoint.
Routes calls through the existing LightGBM model since rf_model.pkl is not available.
"""

from app.services.crop_lgbm_service import predict_crop as _lgbm_predict


def recommend_crops(features: dict):
    """
    Translate /recommend endpoint input format into LightGBM payload
    and return a list of crop dicts compatible with the recommend endpoint.

    features = {
        "soil": {"sand": float, "clay": float, "organicCarbon": float},
        "weather": {"temperature": float, "rainfall": float, "humidity": float},
        "ph": float
    }
    """
    try:
        soil = features.get("soil", {})
        weather = features.get("weather", {})
        ph = float(features.get("ph", 6.5))

        # Map soil composition % to a categorical soil_type for LightGBM
        sand = soil.get("sand") or 0
        clay = soil.get("clay") or 0
        if sand >= 60:
            soil_type = "sandy soil"
        elif clay >= 40:
            soil_type = "clay soil"
        else:
            soil_type = "loamy soil"

        payload = {
            "temperature": weather.get("temperature") or 27.0,
            "humidity": weather.get("humidity") or 65.0,
            "rainfall": weather.get("rainfall") or 100.0,
            "ph": ph,
            "nitrogen": 40.0,
            "carbon": soil.get("organicCarbon") or 1.2,
            "soil_type": soil_type,
        }

        result = _lgbm_predict(payload)

        # Convert LightGBM output to the format expected by /recommend endpoint
        recommendations = []
        for r in result.get("recommendations", []):
            recommendations.append({
                "name": r["crop"],
                "score": r["confidence"],
                "reasons": ["Based on soil texture, pH, and weather conditions"],
                "tips": ["Follow recommended agricultural practices"],
            })

        return recommendations, None

    except Exception as e:
        return None, str(e)
