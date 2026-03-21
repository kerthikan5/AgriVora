import requests
import io
import sys
from PIL import Image

img = Image.new("RGB", (300, 300), color=(139, 90, 43))
buf = io.BytesIO()
img.save(buf, format="JPEG")
buf.seek(0)

r = requests.post("http://localhost:8000/image/texture", files={"file": ("t.jpg", buf, "image/jpeg")}, timeout=120)
body = r.json()
detail = body.get("detail", "")

# Write error as hex-encoded to avoid encoding issues
with open("error_hex.txt", "w") as f:
    for i, c in enumerate(detail):
        f.write(f"{i}:{ord(c):04x}:{c if 32<=ord(c)<127 else '?'} ")
        if (i+1) % 15 == 0:
            f.write("\n")

print(f"STATUS: {r.status_code}, DETAIL_LEN: {len(detail)}")
print("Written hex to error_hex.txt")

# Also write raw ASCII-safe
safe = ''.join(c if 32 <= ord(c) < 127 else '_' for c in detail)
print("SAFE DETAIL:")
print(safe)
