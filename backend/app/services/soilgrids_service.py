"""
**SoilGrids Service**
Responsible for: Making external API calls to the ISRIC SoilGrids REST API to fetch soil properties (pH, organic carbon, nitrogen) via GPS coordinates.
"""

import requests

from app.utils.cache import get_cache, set_cache

SOILGRIDS_URL = "https://rest.isric.org/soilgrids/v2.0/properties/query"

def fetch_soil_data(lat: float, lon: float):
    try:
        # --- Cache key (rounded to reduce duplicates)
        cache_key = f"soil:{round(lat,3)}:{round(lon,3)}"
        cached = get_cache(cache_key)

        if cached:
            print("SOIL CACHE HIT")
            return cached, None

        print("SOIL API CALL")

        params = {
            "lat": lat,
            "lon": lon,
            "property": ["sand", "clay", "soc"],
            "depth": ["0-5cm"]
        }

        response = requests.get(SOILGRIDS_URL, params=params, timeout=6)
        response.raise_for_status()

        data = response.json()
        layers = data.get("properties", {}).get("layers", [])

        soil = {
            "sand": None,
            "clay": None,
            "organicCarbon": None
        }

        for layer in layers:
            name = layer.get("name")
            mean = layer.get("depths", [{}])[0].get("values", {}).get("mean")

            if mean is None:
                continue

            if name == "sand":
                soil["sand"] = round(mean / 10, 2)          # %
            elif name == "clay":
                soil["clay"] = round(mean / 10, 2)          # %
            elif name == "soc":
                soil["organicCarbon"] = round(mean / 100, 2)

        set_cache(cache_key, soil)
        return soil, None

    except Exception as e:
        return None, str(e)
