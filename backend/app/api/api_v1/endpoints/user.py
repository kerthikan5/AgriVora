"""
**User API Endpoint**
Responsible for: Retrieving and updating user profile information.
Dependencies: Firestore.
"""

from datetime import datetime
from typing import Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr

from app.api.api_v1.endpoints.auth import hash_password, verify_password
# from app.utils.firestore import db

router = APIRouter()


# =====================================================
# RESPONSE SCHEMA
# =====================================================

class ProfileResponse(BaseModel):
    user_id: str
    full_name: str
    email: EmailStr
    phone: str
    role: Optional[str]


# =====================================================
# UPDATE SCHEMA
# =====================================================

class UpdateProfileRequest(BaseModel):
    full_name: Optional[str] = None
    phone: Optional[str] = None

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str


# =====================================================
# GET PROFILE
# =====================================================

@router.get("/profile/{user_id}")
def get_profile(user_id: str):

    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")

    user_data = user_doc.to_dict()

    return {
        "success": True,
        "data": {
            "user_id": user_id,
            "full_name": user_data.get("full_name"),
            "email": user_data.get("email"),
            "phone": user_data.get("phone"),
            "role": user_data.get("role")
        },
        "error": None
    }


# =====================================================
# UPDATE PROFILE
# =====================================================

@router.put("/profile/{user_id}")
def update_profile(user_id: str, data: UpdateProfileRequest):

    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")

    update_data = {}

    if data.full_name is not None:
        update_data["full_name"] = data.full_name

    if data.phone is not None:
        update_data["phone"] = data.phone

    update_data["updatedAt"] = datetime.utcnow()

    user_ref.update(update_data)

    return {
        "success": True,
        "message": "Profile updated successfully",
        "error": None
    }


# =====================================================
# CHANGE PASSWORD
# =====================================================

@router.put("/{user_id}/change-password")
def change_password(user_id: str, data: ChangePasswordRequest):
    user_ref = db.collection("users").document(user_id)
    user_doc = user_ref.get()

    if not user_doc.exists:
        raise HTTPException(status_code=404, detail="User not found")

    user_data = user_doc.to_dict()
    stored_hash = user_data.get("password_hash")

    if not stored_hash or not verify_password(data.old_password, stored_hash):
        raise HTTPException(status_code=400, detail="Incorrect old password")

    new_hash = hash_password(data.new_password)
    user_ref.update({"password_hash": new_hash, "updatedAt": datetime.utcnow()})

    return {
        "success": True,
        "message": "Password updated successfully"
    }
