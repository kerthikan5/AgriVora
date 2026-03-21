"""
**Firestore DB Utility**
Responsible for: Maintaining the Firebase Admin initialization and establishing the NoSQL database connection.
"""

from datetime import datetime

import os
from google.cloud import firestore
from google.oauth2 import service_account
from dotenv import load_dotenv

load_dotenv()

# Load credentials securely (Render / Local Dev compatibility)
key_path = os.getenv("FIREBASE_KEY_PATH", "firebase-key.json")

if os.path.exists(key_path):
    print(f"🔒 Authenticating Firestore via Secret File: {key_path}")
    cred = service_account.Credentials.from_service_account_file(key_path)
    db = firestore.Client(credentials=cred)
else:
    print("⚠️ No local key file found. Attempting Default Cloud Credentials.")
    db = firestore.Client()


# -----------------------------
# SAVE SCAN HISTORY
# -----------------------------
def save_scan_history(data: dict):
    try:
        data["createdAt"] = datetime.utcnow()
        db.collection("scan_history").add(data)
        print("Scan saved to Firestore")
        return True
    except Exception as e:
        print("Firestore error:", e)
        return False


# -----------------------------
# GET SCAN HISTORY BY USER
# -----------------------------
def get_scan_history(user_id: str):
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
            
        # Sort in python memory to avoid Firebase Composite Index requirement
        def get_sort_key(x):
            ts = x.get("createdAt")
            if ts is None:
                return "1970"
            try:
                # Firestore usually returns datetime obj here; convert to ISO string to sort safely
                return ts.isoformat()
            except:
                return str(ts)
                
        results.sort(key=get_sort_key, reverse=True)

        return results

    except Exception as e:
        print("Firestore fetch error:", e)
        return []
