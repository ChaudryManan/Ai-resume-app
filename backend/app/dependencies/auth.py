from fastapi import Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, firestore

bearer = HTTPBearer()


def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    try:
        return auth.verify_id_token(credentials.credentials)
    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Firebase token.",
        )


def require_admin(user: dict = Depends(get_current_user)) -> dict:
    # The role lives in Firestore (users/{uid}.role), not in the token.
    snapshot = firestore.client().collection("users").document(user["uid"]).get()
    role = (snapshot.to_dict() or {}).get("role") if snapshot.exists else None

    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required.")

    return user
