"""
**Main Entrypoint**
Responsible for: Initializing the FastAPI application.

Route Summary (all relative to https://agrivora-production.up.railway.app):
  ✅ LIVE (no Firebase needed):
      GET  /              → root
      GET  /health        → health check
      POST /chat          → AI chatbot (OpenAI / g4f fallback)
      POST /location/summary
      POST /recommend     → manual soil form (RandomForest)
      POST /crop/recommend → LightGBM crop predictor
      POST /image/texture → soil CNN (lazy model load via MODEL_URL)
      GET/POST /ph/*      → sensor/pH session endpoints

  ⚠️  FIREBASE-DEPENDENT (requires FIREBASE_CREDENTIALS_JSON env var on Railway):
      POST /api/auth/signup
      POST /api/auth/login
      POST /api/auth/forgot-password/request-otp
      POST /api/auth/forgot-password/verify-otp
      POST /api/auth/forgot-password/reset
      GET  /api/users/profile/{user_id}
      PUT  /api/users/profile/{user_id}
      PUT  /api/users/{user_id}/change-password
      POST /history/save
      GET  /history/{user_id}
      GET  /history/latest/{user_id}
"""

import os
import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# ─── Always-safe imports ───────────────────────────────────────────────────────
from app.api.api_v1.endpoints import chat, location, recommend, sensor
from app.api.crop_lgbm_api import router as crop_lgbm_router
from app.api.api_v1.endpoints import image as image_router

logger = logging.getLogger(__name__)

app = FastAPI(
    title="AgriVora Backend",
    version="1.0.0",
    description="Backend for AgriVora mobile application — deployed on Railway",
)

# ─── CORS ──────────────────────────────────────────────────────────────────────
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Always-enabled routers (no Firebase required) ────────────────────────────
app.include_router(chat.router,          tags=["Chat"])
app.include_router(location.router,      tags=["Location"])
app.include_router(recommend.router,     tags=["Recommend"])
app.include_router(sensor.router,        tags=["Sensor"])
app.include_router(crop_lgbm_router)
app.include_router(image_router.router,  tags=["Image"])

# ─── Firebase-dependent routers ───────────────────────────────────────────────
# These are mounted only when FIREBASE_CREDENTIALS_JSON (or a key file) is present.
# Auth, History, and User profile all talk to Firestore.
_firebase_available = False
try:
    from app.utils.firestore import db  # will raise if credentials are missing
    if db is not None:
        _firebase_available = True
except Exception as _fb_err:
    logger.warning(
        "[startup] Firestore credentials NOT found — auth / history / user-profile routes "
        "will return 503.  Set FIREBASE_CREDENTIALS_JSON in Railway to enable them.  "
        f"Detail: {_fb_err}"
    )

if _firebase_available:
    from app.api.api_v1.endpoints import auth, history, user
    app.include_router(auth.router,    prefix="/api/auth",   tags=["Auth"])
    app.include_router(user.router,    prefix="/api/users",  tags=["Users"])
    app.include_router(history.router,                       tags=["History"])
    logger.info("[startup] ✅ Firebase connected — auth / history / user routes active.")
else:
    # Register stub routes so the app doesn't 404 but gives a clear 503
    from fastapi import APIRouter
    from fastapi.responses import JSONResponse

    _stub = APIRouter()

    _FIREBASE_MSG = (
        "This feature requires Firebase / Firestore.  "
        "Please set the FIREBASE_CREDENTIALS_JSON environment variable on Railway "
        "and redeploy to enable authentication, history, and user-profile features."
    )

    @_stub.api_route(
        "/api/auth/{path:path}",
        methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    )
    async def auth_stub(path: str):
        return JSONResponse(
            status_code=503,
            content={"success": False, "data": None, "error": _FIREBASE_MSG},
        )

    @_stub.api_route(
        "/api/users/{path:path}",
        methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    )
    async def users_stub(path: str):
        return JSONResponse(
            status_code=503,
            content={"success": False, "data": None, "error": _FIREBASE_MSG},
        )

    @_stub.api_route(
        "/history/{path:path}",
        methods=["GET", "POST", "PUT", "DELETE", "PATCH"],
    )
    async def history_stub(path: str):
        return JSONResponse(
            status_code=503,
            content={"success": False, "data": None, "error": _FIREBASE_MSG},
        )

    app.include_router(_stub)


# ─── Root & Health endpoints ──────────────────────────────────────────────────

@app.get("/")
def root():
    return {"message": "AgriVora backend is live"}


@app.get("/health")
def health_check():
    """
    Compatible with both frontend health-check patterns:
      {"status": "ok"}  and  {"success": true}
    """
    return {
        "status": "ok",
        "success": True,
        "data": "Backend is running",
        "firebase": _firebase_available,
        "error": None,
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)