import os
import time
import requests
import jwt
from fastapi import Header, HTTPException, Depends
from sqlalchemy.orm import Session
from database import get_db
import models

FIREBASE_PROJECT_ID = os.getenv("FIREBASE_PROJECT_ID", "digidoc-1202a")
# Default to False but check environment
VERIFY_FIREBASE_TOKEN = os.getenv("VERIFY_FIREBASE_TOKEN", "False").lower() in ("true", "1", "yes")

_public_keys_cache = {"keys": None, "expires_at": 0}

def get_google_public_keys():
    current_time = time.time()
    if _public_keys_cache["keys"] and current_time < _public_keys_cache["expires_at"]:
        return _public_keys_cache["keys"]

    url = "https://www.googleapis.com/robot/v1/metadata/x509/securetoken-system@system.gserviceaccount.com"
    try:
        response = requests.get(url, timeout=10)
        if response.status_code == 200:
            cache_control = response.headers.get("Cache-Control", "")
            max_age = 3600
            for part in cache_control.split(","):
                if "max-age" in part:
                    try:
                        max_age = int(part.split("=")[1])
                    except Exception:
                        pass
            _public_keys_cache["keys"] = response.json()
            _public_keys_cache["expires_at"] = current_time + max_age
            return _public_keys_cache["keys"]
        else:
            raise HTTPException(status_code=500, detail="Failed to fetch Google public keys")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Google certificate fetch error: {str(e)}")

def verify_token(authorization: str = Header(...)) -> dict:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Invalid authorization header format. Must be Bearer <token>")
    
    token = authorization.split(" ")[1]
    
    if not VERIFY_FIREBASE_TOKEN:
        # Dev Mode: Bypass real signature check to facilitate testing without Firebase Config
        try:
            if token.startswith("dev-token-"):
                parts = token.split("-")
                # e.g., dev-token-patient or dev-token-doctor-specialty or dev-token-doctor-Migraine-uid-email
                role = parts[2] if len(parts) > 2 else "patient"
                specialty = parts[3] if len(parts) > 3 else "Pneumonia"
                uid = parts[4] if len(parts) > 4 else f"mock_{role}_uid"
                email = f"{role}@example.com"
                if len(parts) > 5:
                    email = "-".join(parts[5:])
                return {
                    "uid": uid,
                    "email": email,
                    "name": f"Mock {role.capitalize()}",
                    "picture": None,
                    "role": role,
                    "specialty": specialty
                }
            # Fallback to unverified JWT decode
            payload = jwt.decode(token, options={"verify_signature": False})
            return {
                "uid": payload.get("user_id") or payload.get("sub"),
                "email": payload.get("email"),
                "name": payload.get("name"),
                "picture": payload.get("picture"),
                "role": payload.get("role", "patient"),
                "specialty": payload.get("specialty")
            }
        except Exception as e:
            raise HTTPException(status_code=401, detail=f"Dev-mode token decode failed: {str(e)}")

    # Prod Mode: Full Firebase JWT Verification
    try:
        headers = jwt.get_unverified_header(token)
        kid = headers.get("kid")
        if not kid:
            raise HTTPException(status_code=401, detail="Token missing key ID (kid)")
        
        public_keys = get_google_public_keys()
        public_key_pem = public_keys.get(kid)
        if not public_key_pem:
            raise HTTPException(status_code=401, detail="Invalid token key ID (kid)")

        payload = jwt.decode(
            token,
            public_key_pem,
            algorithms=["RS256"],
            audience=FIREBASE_PROJECT_ID,
            issuer=f"https://securetoken.google.com/{FIREBASE_PROJECT_ID}"
        )
        return {
            "uid": payload.get("user_id") or payload.get("sub"),
            "email": payload.get("email"),
            "name": payload.get("name"),
            "picture": payload.get("picture"),
        }
    except jwt.ExpiredSignatureError:
        raise HTTPException(status_code=401, detail="Token has expired")
    except jwt.InvalidTokenError as e:
        raise HTTPException(status_code=401, detail=f"Invalid token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Authentication failed: {str(e)}")

def get_current_user(token_data: dict = Depends(verify_token), db: Session = Depends(get_db)) -> models.User:
    uid = token_data.get("uid")
    user = db.query(models.User).filter(models.User.id == uid).first()
    if not user:
        user = models.User(
            id=uid,
            email=token_data.get("email", ""),
            name=token_data.get("name", "Unknown User"),
            role=token_data.get("role", "patient"),
            profile_pic=token_data.get("picture"),
        )
        db.add(user)
        db.commit()
        db.refresh(user)
    return user
