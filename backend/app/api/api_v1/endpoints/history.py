"""
**History API Endpoint**
Responsible for: Saving and retrieving past soil scan/recommendation history for users.
Dependencies: Firestore history collection.
"""

from datetime import datetime

from fastapi import APIRouter, HTTPException

from app.utils.firestore import get_scan_history

router = APIRouter()


def _serialize(obj):
    """Recursively convert Firestore Timestamps and datetime objects to ISO strings."""
    if isinstance(obj, datetime):
        return obj.isoformat()
    # Firestore DatetimeWithNanoseconds is a subclass of datetime — handled above
    if isinstance(obj, dict):
        return {k: _serialize(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_serialize(i) for i in obj]
    return obj


# =====================================================
# ⚠️  ORDER MATTERS: /history/latest/{user_id} MUST come
#    BEFORE /history/{user_id}, otherwise FastAPI will
#    match "latest" as the {user_id} path parameter.
# =====================================================

# =====================================================
# GET LATEST SCAN (FOR DASHBOARD) — registered first!
# =====================================================

@router.get("/history/latest/{user_id}")
def get_latest_history(user_id: str):
    try:
        results = get_scan_history(user_id)
        if results:
            return {
                "success": True,
                "data": _serialize(results[0]),
                "error": None,
            }
        return {"success": True, "data": None, "error": None}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =====================================================
# SAVE SCAN HISTORY EXPLICITLY
# =====================================================

@router.post("/history/save")
def add_history(data: dict):
    try:
        from app.utils.firestore import save_scan_history
        success = save_scan_history(data)
        if success:
            return {"success": True, "data": "Saved successfully", "error": None}
        raise HTTPException(status_code=500, detail="Firestore save failed")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# =====================================================
# GET FULL SCAN HISTORY — registered last (catch-all)
# =====================================================

@router.get("/history/{user_id}")
def get_history(user_id: str):
    try:
        results = get_scan_history(user_id)
        return {
            "success": True,
            "data": _serialize(results),
            "error": None,
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
