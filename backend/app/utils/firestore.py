"""
**Firestore DB Utility**
Responsible for: Maintaining the Firebase Admin initialization and establishing the NoSQL database connection.

On Railway: set the FIREBASE_CREDENTIALS_JSON environment variable to the contents of your
firebase-key.json file (as a single-line JSON string) to enable Firestore-backed features.

If credentials are missing, `db` will be None and the caller (main.py) will register
503-stub routes instead, so the app still starts and all non-Firebase features work.
"""

import json
import logging
import os
from datetime import datetime

from dotenv import load_dotenv

logger = logging.getLogger(__name__)
load_dotenv()

db = None  # Will be set below if credentials are available.

# ─── Attempt to initialise Firestore ─────────────────────────────────────────
key_path = os.getenv("FIREBASE_KEY_PATH", "firebase-key.json")
firebase_cred_json = os.getenv("FIREBASE_CREDENTIALS_JSON")

try:
    from google.cloud import firestore
    from google.oauth2 import service_account

    if firebase_cred_json and firebase_cred_json.strip():
        logger.info("🔒 Authenticating Firestore via FIREBASE_CREDENTIALS_JSON env var")
        cred_info = json.loads(firebase_cred_json)
        cred = service_account.Credentials.from_service_account_info(cred_info)
        db = firestore.Client(credentials=cred)
        logger.info("✅ Firestore connected successfully (env var).")

    elif os.path.exists(key_path):
        logger.info(f"🔒 Authenticating Firestore via key file: {key_path}")
        cred = service_account.Credentials.from_service_account_file(key_path)
        db = firestore.Client(credentials=cred)
        logger.info("✅ Firestore connected successfully (key file).")

    else:
        logger.warning(
            "⚠️ No FIREBASE_CREDENTIALS_JSON env var and no firebase-key.json found. "
            "Auth / history / profile features will be disabled. "
            "Add FIREBASE_CREDENTIALS_JSON to Railway environment variables to activate them."
        )
        db = None

except Exception as e:
    logger.error(
        f"❌ Firestore initialisation failed: {e}. "
        "Auth / history / profile features will be disabled."
    )
    db = None


# ─── Helpers (safe to call; return gracefully if db is None) ─────────────────

def save_scan_history(data: dict) -> bool:
    if db is None:
        logger.warning("save_scan_history: Firestore not available.")
        return False
    try:
        data["createdAt"] = datetime.utcnow()
        db.collection("scan_history").add(data)
        logger.debug("Scan saved to Firestore.")
        return True
    except Exception as e:
        logger.error(f"Firestore save error: {e}")
        return False


def get_scan_history(user_id: str) -> list:
    if db is None:
        logger.warning("get_scan_history: Firestore not available.")
        return []
    try:
        docs = (
            db.collection("scan_history")
            .where("userId", "==", user_id)
            .stream()
        )

        results = []
        for doc in docs:
            item = doc.to_dict()
            item["id"] = doc.id
            results.append(item)

        def get_sort_key(x):
            ts = x.get("createdAt")
            if ts is None:
                return "1970"
            try:
                return ts.isoformat()
            except Exception:
                return str(ts)

        results.sort(key=get_sort_key, reverse=True)
        return results

    except Exception as e:
        logger.error(f"Firestore fetch error: {e}")
        return []
