"""backend/app/routers/matching.py  (replace the commented-out prototype)

Register in main.py:
    from app.routers import matching
    app.include_router(matching.router)
"""
from fastapi import APIRouter, Depends, HTTPException

from app.schemas.job_matching_schema import MatchResponse
from app.services.matching_service import match_job

# ADAPT: import the same get_current_user dependency your resumes router uses
from app.dependencies.auth import get_current_user

router = APIRouter(prefix="/api/jobs", tags=["matching"])


@router.post("/{job_id}/match", response_model=MatchResponse)
async def run_matching(job_id: str, top_n: int = 20, applicants_only: bool = False,
                       user: dict = Depends(get_current_user)):
    # ADAPT: however you store the role (Firestore users/{uid}.role or a custom claim)
    if user.get("role") != "admin":
        raise HTTPException(status_code=403, detail="Admins only")
    try:
        return await match_job(job_id, top_n=top_n, applicants_only=applicants_only)
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))