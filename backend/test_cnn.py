"""
Run: .venv\Scripts\python.exe test_cnn.py
Tests the /image/texture endpoint with a synthetic image.
Note: first call may take ~30s while the model loads in the background.
"""
import requests
import io
from PIL import Image

# Create a simple 300x300 brown-ish test image (simulating soil photo)
img = Image.new("RGB", (300, 300), color=(139, 90, 43))
buf = io.BytesIO()
img.save(buf, format="JPEG")
buf.seek(0)

print("Sending test image to /image/texture (may take ~30s on first call) ...")
try:
    resp = requests.post(
        "http://localhost:8000/image/texture",
        files={"file": ("test.jpg", buf, "image/jpeg")},
        timeout=200,  # generous timeout for model load + inference
    )
    print(f"Status: {resp.status_code}")
    import json
    print(json.dumps(resp.json(), indent=2))
except Exception as e:
    print(f"Error: {e}")
