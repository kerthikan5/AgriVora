import requests, json, sys, os

BASE = "http://127.0.0.1:8000"
results = []

def check(name, ok, detail=""):
    status = "PASS" if ok else "FAIL"
    print(f"  [{status}] {name}")
    if detail:
        print(f"         {detail[:200]}")
    results.append((name, ok))

# ─── 1. Health ─────────────────────────────────────────────
print("\n=== 1. Health Check ===")
try:
    r = requests.get(f"{BASE}/health", timeout=10)
    d = r.json()
    check("GET /health -> 200", r.status_code == 200, str(d))
    check("health success==true", d.get("success") == True)
except Exception as e:
    check("GET /health", False, str(e))

# ─── 2. Auth ───────────────────────────────────────────────
print("\n=== 2. Auth Endpoints ===")
email = "testcheck_agrivora@example.com"
pw = "TestPass123!"
try:
    r = requests.post(f"{BASE}/api/auth/signup", json={
        "full_name": "Test", "email": email,
        "phone": "9999999990", "password": pw
    }, timeout=20)
    d = r.json()
    check("POST /api/auth/signup", r.status_code in (200, 400), str(d)[:150])
except Exception as e:
    check("POST /api/auth/signup", False, str(e))

uid = None
try:
    r = requests.post(f"{BASE}/api/auth/login", json={
        "email_or_phone": email, "password": pw
    }, timeout=20)
    d = r.json()
    ok = r.status_code == 200 and d.get("success") == True
    check("POST /api/auth/login", ok, str(d)[:150] if not ok else "")
    uid = d.get("user_id") if ok else None
    if uid:
        print(f"         uid = {uid}")
except Exception as e:
    check("POST /api/auth/login", False, str(e))

# ─── 3. User Profile ───────────────────────────────────────
print("\n=== 3. User Profile ===")
if uid:
    try:
        r = requests.put(f"{BASE}/api/users/profile/{uid}", json={"full_name": "Updated Name"}, timeout=20)
        d = r.json()
        check("PUT /api/users/profile/{uid}", r.status_code == 200 and d.get("success"), str(d)[:150] if r.status_code != 200 else "")
    except Exception as e:
        check("PUT /api/users/profile/{uid}", False, str(e))

    try:
        r = requests.put(f"{BASE}/api/users/{uid}/change-password", json={
            "old_password": pw, "new_password": pw
        }, timeout=20)
        d = r.json()
        check("PUT /api/users/{uid}/change-password", r.status_code == 200 and d.get("success"), str(d)[:150] if r.status_code != 200 else "")
    except Exception as e:
        check("PUT /api/users/{uid}/change-password", False, str(e))
else:
    print("  [SKIP] No uid from login - skipping profile tests")

# ─── 4. History ────────────────────────────────────────────
print("\n=== 4. History Endpoints ===")
test_uid = uid or "fake-test-uid"
try:
    r = requests.get(f"{BASE}/history/{test_uid}", timeout=15)
    d = r.json()
    n = len(d.get("data", [])) if isinstance(d.get("data"), list) else "?"
    check("GET /history/{uid}", r.status_code == 200 and d.get("success"), str(d)[:150] if r.status_code != 200 else f"records={n}")
except Exception as e:
    check("GET /history/{uid}", False, str(e))

try:
    r = requests.get(f"{BASE}/history/latest/{test_uid}", timeout=15)
    d = r.json()
    check("GET /history/latest/{uid}", r.status_code == 200 and d.get("success"), str(d)[:150] if r.status_code != 200 else "")
except Exception as e:
    check("GET /history/latest/{uid}", False, str(e))

try:
    r = requests.post(f"{BASE}/history/save", json={
        "userId": test_uid, "ph": 6.5, "results": ["Rice"], "createdAt": "2026-01-01"
    }, timeout=15)
    d = r.json()
    check("POST /history/save", r.status_code == 200 and d.get("success"), str(d)[:150] if r.status_code != 200 else "")
except Exception as e:
    check("POST /history/save", False, str(e))

# ─── 5. /recommend camelCase (what backend expects) ────────
print("\n=== 5a. POST /recommend (camelCase - what backend expects) ===")
try:
    r = requests.post(f"{BASE}/recommend", json={
        "userId": test_uid, "soilType": "Loamy",
        "ph": 6.5, "temperature": 25.0, "rainfall": 120.0, "humidity": 65.0
    }, timeout=20)
    d = r.json()
    ok = r.status_code == 200 and d.get("success") == True
    detail = str(d.get("data", {}))[:100] if ok else str(d)[:200]
    check("POST /recommend (camelCase)", ok, detail)
except Exception as e:
    check("POST /recommend (camelCase)", False, str(e))

print("\n=== 5b. POST /recommend (snake_case - what FRONTEND sends!) ===")
try:
    r = requests.post(f"{BASE}/recommend", json={
        "user_id": test_uid, "soil_type": "Loamy",
        "ph": 6.5, "temperature": 25.0, "rainfall": 120.0, "humidity": 65.0
    }, timeout=20)
    d = r.json()
    ok = r.status_code == 200 and d.get("success") == True
    check("POST /recommend (snake_case)", ok, "MISMATCH - needs camelCase but frontend sends snake_case!" if not ok else "OK")
except Exception as e:
    check("POST /recommend (snake_case)", False, str(e))

# ─── 6. LightGBM /crop/recommend ──────────────────────────
print("\n=== 6. POST /crop/recommend (LightGBM) ===")
try:
    r = requests.post(f"{BASE}/crop/recommend", json={
        "user_id": test_uid, "temperature": 26.0, "humidity": 65.0,
        "rainfall": 150.0, "ph": 6.5, "nitrogen": 50.0, "carbon": 1.5,
        "soil_type": "loamy soil"
    }, timeout=30)
    d = r.json()
    ok = r.status_code == 200
    check("POST /crop/recommend", ok, str(d)[:200] if not ok else f"crop={d.get('recommended_crop')}, conf={d.get('confidence')}")
except Exception as e:
    check("POST /crop/recommend", False, str(e))

# ─── 7. Soil CNN /soil/predict ─────────────────────────────
print("\n=== 7. POST /soil/predict (CNN) ===")
try:
    path = "test_soil.jpg"
    if os.path.exists(path):
        with open(path, "rb") as f:
            r = requests.post(f"{BASE}/soil/predict", files={"file": ("test_soil.jpg", f, "image/jpeg")}, timeout=120)
        d = r.json()
        ok = r.status_code == 200 and d.get("success") == True
        check("POST /soil/predict", ok, str(d)[:200] if not ok else f"soil={d.get('data',{}).get('soil_type')}, conf={d.get('data',{}).get('confidence')}")
    else:
        check("POST /soil/predict", False, "test_soil.jpg not found in backend dir")
except Exception as e:
    check("POST /soil/predict", False, str(e))

# ─── 8. Image texture /image/texture ──────────────────────
print("\n=== 8. POST /image/texture (App soil scan) ===")
try:
    path = "test_soil.jpg"
    if os.path.exists(path):
        with open(path, "rb") as f:
            r = requests.post(f"{BASE}/image/texture", files={"file": ("test_soil.jpg", f, "image/jpeg")}, timeout=120)
        d = r.json()
        ok = r.status_code == 200 and d.get("success") == True
        check("POST /image/texture", ok, str(d)[:200] if not ok else f"texture={d.get('data',{}).get('texture')}, conf={d.get('data',{}).get('confidence')}")
    else:
        check("POST /image/texture", False, "test_soil.jpg not found")
except Exception as e:
    check("POST /image/texture", False, str(e))

# ─── 9. Location Summary ───────────────────────────────────
print("\n=== 9. POST /location/summary ===")
try:
    r = requests.post(f"{BASE}/location/summary", json={"lat": 12.9716, "lon": 77.5946}, timeout=30)
    d = r.json()
    ok = r.status_code == 200 and d.get("success") == True
    check("POST /location/summary", ok, str(d)[:250] if not ok else f"keys={list(d.get('data',{}).keys())}")
except Exception as e:
    check("POST /location/summary", False, str(e))

# ─── 10. Chat AI ───────────────────────────────────────────
print("\n=== 10. POST /chat (AI) ===")
try:
    r = requests.post(f"{BASE}/chat", json={"message": "Best crop for sandy soil?"}, timeout=60)
    d = r.json()
    ok = r.status_code == 200 and d.get("success") == True
    check("POST /chat", ok, str(d)[:200] if not ok else "reply received")
except Exception as e:
    check("POST /chat", False, str(e))

# ─── 11. Sensor ────────────────────────────────────────────
print("\n=== 11. Sensor Endpoints ===")
try:
    r = requests.get(f"{BASE}/ph/search_device", timeout=15)
    check("GET /ph/search_device", r.status_code in (200, 404, 500), r.text[:100])
except Exception as e:
    check("GET /ph/search_device", False, str(e))

try:
    r = requests.get(f"{BASE}/ph/live/guest", timeout=15)
    check("GET /ph/live/guest", r.status_code in (200, 404, 500), r.text[:100])
except Exception as e:
    check("GET /ph/live/guest", False, str(e))

# ─── Summary ───────────────────────────────────────────────
print("\n" + "="*55)
print("FINAL SUMMARY")
print("="*55)
passed = sum(1 for _, ok in results if ok)
total = len(results)
print(f"Passed: {passed}/{total}")
for name, ok in results:
    print(f"  {'PASS' if ok else 'FAIL'} | {name}")
if passed < total:
    sys.exit(1)
