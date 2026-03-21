import requests
import time

url = "http://localhost:8000/sensor/ph/123"

for _ in range(3):
    try:
        r = requests.get(url)
        print(r.json())
    except Exception as e:
        print("Error:", e)
    time.sleep(2)
