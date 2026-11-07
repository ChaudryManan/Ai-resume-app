import logging

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore

from app.dependencies.auth import require_admin
from app.services.supabase_client import get_supabase

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/candidates", tags=["candidates"])

RESUME_LINK_SECONDS = 600


@router.get("/{uid}/resume")
def get_candidate_resume_link(
    uid: str,
    admin: dict = Depends(require_admin),
):
    """A short-lived link an admin can open to read a candidate's resume PDF."""
    snapshot = firestore.client().collection("resumes").document(uid).get()
    if not snapshot.exists:
        raise HTTPException(status_code=404, detail="This candidate has no resume.")

    data = snapshot.to_dict() or {}
    storage_path = data.get("storagePath")

    if not storage_path or data.get("bucket") != "resumes":
        raise HTTPException(status_code=400, detail="Invalid resume storage information.")

    if not storage_path.startswith(f"{uid}/"):
        raise HTTPException(status_code=403, detail="Invalid resume ownership.")

    try:
        signed = get_supabase().storage.from_("resumes").create_signed_url(
            storage_path, RESUME_LINK_SECONDS
        )
        url = signed.get("signedURL") or signed.get("signedUrl")
    except Exception as error:
        logger.exception("Could not sign the resume link for %s", uid)
        raise HTTPException(
            status_code=500, detail="Could not create a link to the resume."
        ) from error

    if not url:
        raise HTTPException(status_code=404, detail="Resume file was not found in storage.")

    return {
        "url": url,
        "file_name": data.get("fileName"),
        "expires_in": RESUME_LINK_SECONDS,
    }
