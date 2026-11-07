import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException, Query
from firebase_admin import firestore

from app.dependencies.auth import require_admin
from app.schemas.job_matching_schema import (
    HIGHLY_ELIGIBLE_MIN,
    POTENTIAL_MIN,
    CandidateMatch,
)
from app.services.matching_service import (
    JobNotFoundError,
    MatchAlreadyRunningError,
    run_job_matching,
    run_matching_in_background,
    start_job_matching,
)

logger = logging.getLogger(__name__)

router = APIRouter(prefix="/api/jobs", tags=["matching"])


@router.post("/{job_id}/match")
async def run_matching(
    job_id: str,
    background_tasks: BackgroundTasks,
    top_n: int = Query(20, ge=1, le=100),
    applicants_only: bool = False,
    background: bool = False,
    admin: dict = Depends(require_admin),
):
    """
    Match a job with every screened resume (or only its applicants).

    background=false: wait for the result (handy for testing in /docs).
    background=true : return immediately; poll GET /matches for matchStatus.
    """
    try:
        if background:
            start_job_matching(job_id)
            background_tasks.add_task(
                run_matching_in_background, job_id, applicants_only
            )
            return {"status": "started", "job_id": job_id}

        return await run_job_matching(
            job_id, top_n=top_n, applicants_only=applicants_only
        )
    except JobNotFoundError:
        raise HTTPException(status_code=404, detail="Job not found.")
    except MatchAlreadyRunningError:
        raise HTTPException(
            status_code=409, detail="Matching is already running for this job."
        )
    except Exception as error:
        logger.exception("Matching failed for job %s", job_id)
        raise HTTPException(status_code=500, detail="Matching failed.") from error


@router.get("/{job_id}/matches")
def get_matches(
    job_id: str,
    limit: int = Query(50, ge=1, le=200),
    admin: dict = Depends(require_admin),
):
    """Read the ranked results saved by the last matching run."""
    db = firestore.client()

    job_snapshot = db.collection("jobs").document(job_id).get()
    if not job_snapshot.exists:
        raise HTTPException(status_code=404, detail="Job not found.")
    job = job_snapshot.to_dict() or {}

    documents = (
        db.collection("jobs")
        .document(job_id)
        .collection("matches")
        .order_by("rank")
        .limit(limit)
        .stream()
    )

    results = []
    for document in documents:
        data = document.to_dict() or {}
        try:
            # Re-validating also fills fields that older saved results lack
            # (e.g. eligibility) and drops the non-JSON Firestore timestamp.
            result = CandidateMatch.model_validate(data).model_dump()
        except Exception:
            logger.warning("Skipping unreadable match %s for job %s", document.id, job_id)
            continue
        result["rank"] = data.get("rank")
        results.append(result)

    matched_at = job.get("matchedAt")

    return {
        "job_id": job_id,
        "job_title": job.get("title"),
        "match_status": job.get("matchStatus", "not_started"),
        "match_error": job.get("matchError"),
        "matched_at": matched_at.isoformat() if matched_at else None,
        "evaluated": job.get("matchEvaluated"),
        "failed": job.get("matchFailed"),
        "skipped_no_profile": job.get("matchSkippedNoProfile"),
        "thresholds": {
            "highly_eligible": HIGHLY_ELIGIBLE_MIN,
            "potential": POTENTIAL_MIN,
        },
        "results": results,
    }
