"""
**Auth API Endpoint**
Responsible for: Handling user registration (signup) and login.
Inputs/Outputs: Accepts email/phone+pwd, returns user ID and session details. Also handles password reset OTP process.
Dependencies: Firebase config / Authentication utils.
"""

import hashlib
import random
import uuid
from datetime import datetime, timedelta

import bcrypt
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr, Field

from app.utils.email import send_otp_email
from app.utils.firestore import db

router = APIRouter()

# =====================================================
# REQUEST SCHEMAS
# =====================================================

class SignUpRequest(BaseModel):
    full_name: str = Field(..., min_length=1)
    email: EmailStr
    phone: str = Field(..., min_length=6)
    password: str = Field(..., min_length=8)

class LoginRequest(BaseModel):
    email_or_phone: str = Field(..., min_length=1)
    password: str = Field(..., min_length=8)

class RequestOTPRequest(BaseModel):
    email: EmailStr

class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str

class ResetPasswordRequest(BaseModel):
    email: EmailStr
    otp: str
    new_password: str = Field(..., min_length=8)


# =====================================================
# HELPER FUNCTIONS (SAFE AGAINST 72-BYTE LIMIT)
# =====================================================

def _pw_digest(password: str) -> bytes:
    """
    Returns a fixed-length 32-byte digest, so bcrypt never sees >72 bytes.
    """
    return hashlib.sha256(password.encode("utf-8")).digest()

def hash_password(password: str) -> str:
    """
    Hash SHA256(password) using bcrypt.
    Stores as a utf-8 string.
    """
    digest = _pw_digest(password)
    hashed = bcrypt.hashpw(digest, bcrypt.gensalt())
    return hashed.decode("utf-8")

def verify_password(plain_password: str, hashed_password: str) -> bool:
    digest = _pw_digest(plain_password)
    return bcrypt.checkpw(digest, hashed_password.encode("utf-8"))


# =====================================================
# SIGNUP ENDPOINT
# =====================================================

@router.post("/signup")
def create_account(data: SignUpRequest):
    try:
        users_ref = db.collection("users")

        full_name = data.full_name.strip()
        email = data.email.strip().lower()
        phone = data.phone.strip()
        password = data.password

        # Check if email exists
        existing_email = users_ref.where("email", "==", email).limit(1).stream()
        for _ in existing_email:
            raise HTTPException(status_code=400, detail="Email already registered")

        # Check if phone exists
        existing_phone = users_ref.where("phone", "==", phone).limit(1).stream()
        for _ in existing_phone:
            raise HTTPException(status_code=400, detail="Phone number already registered")

        user_id = str(uuid.uuid4())
        password_hash = hash_password(password)

        users_ref.document(user_id).set({
            "full_name": full_name,
            "email": email,
            "phone": phone,
            "password_hash": password_hash,
            "role": None,
            "acceptedTerms": False,
            "onboardingCompleted": False,
            "createdAt": datetime.utcnow(),
        })

        return {
            "success": True,
            "message": "Account created successfully",
            "user_id": user_id,
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


# =====================================================
# LOGIN ENDPOINT
# =====================================================

@router.post("/login")
def login_user(data: LoginRequest):
    try:
        users_ref = db.collection("users")

        identifier = data.email_or_phone.strip()
        password = data.password

        user_doc = None

        # Try email
        query = users_ref.where("email", "==", identifier.lower()).limit(1).stream()
        for doc in query:
            user_doc = doc
            break

        # Try phone
        if not user_doc:
            query = users_ref.where("phone", "==", identifier).limit(1).stream()
            for doc in query:
                user_doc = doc
                break

        if not user_doc:
            raise HTTPException(status_code=404, detail="User not found")

        user_data = user_doc.to_dict()

        stored_hash = user_data.get("password_hash") or user_data.get("password")
        if not stored_hash:
            raise HTTPException(status_code=500, detail="Server error: password hash missing")

        if not verify_password(password, stored_hash):
            raise HTTPException(status_code=401, detail="Invalid password")

        return {
            "success": True,
            "message": "Login successful",
            "user_id": user_doc.id,
            "full_name": user_data.get("full_name"),
            "email": user_data.get("email"),
            "phone": user_data.get("phone"),
            "role": user_data.get("role"),
            "onboardingCompleted": user_data.get("onboardingCompleted", False),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


# =====================================================
# FORGOT PASSWORD - REQUEST OTP
# =====================================================

@router.post("/forgot-password/request-otp")
def request_otp(data: RequestOTPRequest):
    try:
        email = data.email.strip().lower()

        # 1. Check if user exists
        users_ref = db.collection("users")
        user_query = users_ref.where("email", "==", email).limit(1).stream()
        user_found = False
        for _ in user_query:
            user_found = True
            break
        
        if not user_found:
            raise HTTPException(status_code=404, detail="User with this email not found")

        # 2. Generate 6-digit OTP
        otp = str(random.randint(100000, 999999))

        # 3. Save OTP to Firestore (expire in 10 mins)
        otp_ref = db.collection("otps").document(email)
        otp_ref.set({
            "email": email,
            "otp": otp,
            "createdAt": datetime.utcnow(),
            "expiresAt": datetime.utcnow() + timedelta(minutes=10)
        })

        # 4. Send Email
        success = send_otp_email(email, otp)
        if not success:
            raise HTTPException(status_code=500, detail="Failed to send email. Check SMTP settings.")

        return {
            "success": True,
            "message": "OTP sent to your email"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


# =====================================================
# FORGOT PASSWORD - VERIFY OTP
# =====================================================

@router.post("/forgot-password/verify-otp")
def verify_otp_endpoint(data: VerifyOTPRequest):
    try:
        email = data.email.strip().lower()
        otp = data.otp.strip()

        # 1. Get OTP from Firestore
        otp_doc = db.collection("otps").document(email).get()
        if not otp_doc.exists:
            raise HTTPException(status_code=400, detail="No OTP requested for this email")

        otp_data = otp_doc.to_dict()

        # 2. Check if expired
        if datetime.utcnow().timestamp() > otp_data['expiresAt'].timestamp():
            raise HTTPException(status_code=400, detail="OTP has expired")

        # 3. Check if matches
        if otp_data['otp'] != otp:
             raise HTTPException(status_code=400, detail="Invalid OTP")

        return {
            "success": True,
            "message": "OTP verified successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")


# =====================================================
# FORGOT PASSWORD - RESET
# =====================================================

@router.post("/forgot-password/reset")
def reset_password_endpoint(data: ResetPasswordRequest):
    try:
        email = data.email.strip().lower()
        otp = data.otp.strip()
        new_password = data.new_password

        # 1. Re-verify OTP for security
        otp_doc = db.collection("otps").document(email).get()
        if not otp_doc.exists:
             raise HTTPException(status_code=400, detail="Invalid request")

        otp_data = otp_doc.to_dict()
        if otp_data['otp'] != otp or datetime.utcnow().timestamp() > otp_data['expiresAt'].timestamp():
            raise HTTPException(status_code=400, detail="OTP expired or invalid")

        # 2. Update User Password
        users_ref = db.collection("users")
        user_query = users_ref.where("email", "==", email).limit(1).stream()
        user_id = None
        for doc in user_query:
            user_id = doc.id
            break
        
        if not user_id:
            raise HTTPException(status_code=404, detail="User not found")

        hashed_password = hash_password(new_password)
        users_ref.document(user_id).update({
            "password_hash": hashed_password
        })

        # 3. Delete OTP record
        db.collection("otps").document(email).delete()

        return {
            "success": True,
            "message": "Password reset successfully"
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Server error: {str(e)}")