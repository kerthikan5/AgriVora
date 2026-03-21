"""
**Sensor Endpoint**
Responsible for: Managing hardware IoT sensor requests (e.g., pH readings if routed through backend proxy).
"""

import logging
import statistics
import uuid
from collections import deque
from datetime import datetime, timezone
from typing import List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

router = APIRouter()
logger = logging.getLogger(__name__)

# ─── In-memory stores (replace with Firestore/DB in production) ───────────────
# Stores: { sessionId -> { "userId", "deviceId", "readings": [...], "startedAt" } }
_sessions: dict = {}
# Last 50 readings per user (for quick live-view endpoint)
_live_cache: dict = {}   # userId -> deque(maxlen=50)

# ─── Models ───────────────────────────────────────────────────────────────────

class GpsPoint(BaseModel):
    lat: float
    lng: float

class PhReadingIn(BaseModel):
    ph: float          = Field(..., ge=0.0, le=14.0, description="pH value 0–14")
    voltage: Optional[float] = None
    temperature: Optional[float] = None
    gps: Optional[GpsPoint] = None
    capturedAt: Optional[str] = None   # ISO-8601 from phone clock

class BulkUpload(BaseModel):
    sessionId: str
    deviceId:  str
    readings:  List[PhReadingIn]

class SessionStart(BaseModel):
    userId:   str
    deviceId: str
    gps:      Optional[GpsPoint] = None

class SessionEnd(BaseModel):
    sessionId: str


# ─── Helper ───────────────────────────────────────────────────────────────────

def _compute_summary(readings: list) -> dict:
    """Compute aggregate stats for a session's readings."""
    ph_vals = [r["ph"] for r in readings if r.get("ph") is not None]
    if not ph_vals:
        return {}
    avg = round(statistics.mean(ph_vals), 2)
    mn  = round(min(ph_vals), 2)
    mx  = round(max(ph_vals), 2)
    stdev = round(statistics.stdev(ph_vals), 3) if len(ph_vals) > 1 else 0.0

    # Stability score: 0–100; lower stdev = more stable
    stability = max(0, round(100 - stdev * 100, 1))

    category = ("Strongly Acidic" if avg < 5.5 else
                 "Acidic"          if avg < 6.5 else
                 "Neutral"         if avg < 7.5 else
                 "Alkaline"        if avg < 8.5 else
                 "Strongly Alkaline")

    tip = None
    if avg < 5.5:
        tip = "Soil pH is too low. Consider adding lime (calcium carbonate) to raise pH."
    elif avg > 7.5:
        tip = "Soil pH is too high. Consider adding sulfur or organic compost to lower pH."

    return {
        "avgPh":         avg,
        "minPh":         mn,
        "maxPh":         mx,
        "stdev":         stdev,
        "stabilityScore": stability,
        "category":      category,
        "improvementTip": tip,
        "count":         len(ph_vals),
    }


def _validate_readings(readings: List[PhReadingIn]) -> List[dict]:
    """Validate pH range (0–14) and filter spikes (>1.0 step change)."""
    valid = []
    prev  = None
    for r in readings:
        if r.ph < 0 or r.ph > 14:
            logger.warning(f"Discarding out-of-range pH {r.ph}")
            continue
        if prev is not None and abs(r.ph - prev) > 1.0:
            logger.warning(f"Discarding spike jump {prev}→{r.ph}")
            continue
        prev = r.ph
        valid.append(r.model_dump())
    return valid


# ─── Endpoints ────────────────────────────────────────────────────────────────

@router.post("/ph/sessions/start")
async def start_session(body: SessionStart):
    """Create a new pH reading session and return a sessionId."""
    session_id = str(uuid.uuid4())
    _sessions[session_id] = {
        "sessionId":  session_id,
        "userId":     body.userId,
        "deviceId":   body.deviceId,
        "startedAt":  datetime.now(timezone.utc).isoformat(),
        "endedAt":    None,
        "gps":        body.gps.model_dump() if body.gps else None,
        "readings":   [],
        "summary":    {},
    }
    logger.info(f"Session started: {session_id} for user {body.userId}")
    return {"success": True, "data": {"sessionId": session_id}, "error": None}


@router.post("/ph/sessions/{session_id}/readings/bulk")
async def bulk_upload(session_id: str, body: BulkUpload):
    """Accept a batch of pH readings from the phone every 10–30 seconds."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    validated = _validate_readings(body.readings)
    session   = _sessions[session_id]
    session["readings"].extend(validated)

    # Update live cache for the session owner
    uid = session["userId"]
    if uid not in _live_cache:
        _live_cache[uid] = deque(maxlen=50)
    _live_cache[uid].extend(validated)

    logger.info(f"Bulk upload: {len(validated)} readings → session {session_id}")
    return {
        "success": True,
        "data": {
            "accepted": len(validated),
            "discarded": len(body.readings) - len(validated),
        },
        "error": None,
    }


@router.post("/ph/sessions/{session_id}/end")
async def end_session(session_id: str):
    """Finalise session and compute analytics summary."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")

    session = _sessions[session_id]
    session["endedAt"] = datetime.now(timezone.utc).isoformat()
    session["summary"] = _compute_summary(session["readings"])

    logger.info(f"Session ended: {session_id}, summary={session['summary']}")
    return {"success": True, "data": session, "error": None}


@router.get("/ph/sessions")
async def list_sessions(userId: str, limit: int = 20):
    """Return most recent N sessions for a user."""
    user_sessions = [
        s for s in _sessions.values()
        if s["userId"] == userId
    ]
    # Sort newest first
    user_sessions.sort(key=lambda s: s["startedAt"], reverse=True)
    return {
        "success": True,
        "data": user_sessions[:limit],
        "error": None,
    }


@router.get("/ph/sessions/{session_id}")
async def get_session(session_id: str):
    """Return a single session with its full readings and summary."""
    if session_id not in _sessions:
        raise HTTPException(status_code=404, detail="Session not found")
    return {"success": True, "data": _sessions[session_id], "error": None}


@router.get("/ph/live/{user_id}")
async def get_live(user_id: str):
    """Return the latest cached pH reading for a user (most recent bulk upload)."""
    cache = _live_cache.get(user_id, deque())
    if not cache:
        return {
            "success": True,
            "data": {"ph": None, "message": "No readings yet. Start a session."},
            "error": None,
        }
    latest = list(cache)[-1]
    return {
        "success": True,
        "data": {
            "ph":          latest.get("ph"),
            "voltage":     latest.get("voltage"),
            "temperature": latest.get("temperature"),
            "capturedAt":  latest.get("capturedAt"),
            "message":     "Live data from last bulk upload",
        },
        "error": None,
    }

@router.get("/ph/search_device")
async def search_device():
    """Mock endpoint to search for available ESP32 devices."""
    import asyncio
    try:
        # Mocking a list of available devices
        await asyncio.sleep(1.5)
        devices = [
            {"device": "AgriVora_pH_ESP32", "mac": "70:4B:CA:8D:A7:86", "status": "available"},
            {"device": "AgriVora_pH_Sensor_02", "mac": "12:34:56:78:9A:BC", "status": "available"},
            {"device": "SoilLab_Pro_03", "mac": "DE:AD:BE:EF:00:11", "status": "available"}
        ]
        return {
            "success": True,
            "data": {"devices": devices},
            "error": None
        }
    except Exception as e:
        return {
            "success": False,
            "data": None,
            "error": str(e)
        }
