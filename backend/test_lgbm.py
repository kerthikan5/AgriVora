import os
import sys

# Ensure backend directory is in the python path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app.services.crop_lgbm_service import predict_crop

print("PH 8:", predict_crop({
    "ph": 8.0,
    "temperature": 25.0,
    "humidity": 65.0,
    "rainfall": 100.0,
    "nitrogen": 40.0,
    "carbon": 1.2,
    "soil_type": "loamy soil"
}))

print("PH 5:", predict_crop({
    "ph": 5.0,
    "temperature": 25.0,
    "humidity": 65.0,
    "rainfall": 100.0,
    "nitrogen": 40.0,
    "carbon": 1.2,
    "soil_type": "loamy soil"
}))
