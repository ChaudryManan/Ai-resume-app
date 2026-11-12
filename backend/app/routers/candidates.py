import logging

from fastapi import APIRouter, Depends, HTTPException
from firebase_admin import firestore

from app.dependencies.auth import get_current_user, require_admin
from app.schemas.job_matching_schema import (
    HIGHLY_ELIGIBLE_MIN,
    POTENTIAL_MIN,
    CandidateMatch,
)
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


def _count_skills(skill_lists: list[list[str]], limit: int = 8) -> list[dict]:
    """How many jobs each skill appears in (case-insensitive), most common first."""
    counts: dict[str, int] = {}
    labels: dict[str, str] = {}

    for skills in skill_lists:
        seen: set[str] = set()
        for skill in skills:
            if not isinstance(skill, str):
                continue
            label = skill.strip()
            key = label.lower()
            if not key or key in seen:
                continue
            seen.add(key)
            labels.setdefault(key, label)
            counts[key] = counts.get(key, 0) + 1

    ranked = sorted(counts.items(), key=lambda item: (-item[1], item[0]))[:limit]
    return [{"skill": labels[key], "count": count} for key, count in ranked]


@router.get("/me/insights")
def get_my_insights(user: dict = Depends(get_current_user)):
    """
    The signed-in candidate's own parsed profile and how their resume scored
    against every open job.

    Only the caller's own data is returned: nothing about other candidates
    (no ranks, names or scores), and no red flags or knock-out reasons.
    Jobs that no recruiter has run matching for yet simply have no entry.
    """
    uid = user["uid"]
    db = firestore.client()

    profile_snapshot = db.collection("candidate_profiles").document(uid).get()
    profile = None
    if profile_snapshot.exists:
        profile = (profile_snapshot.to_dict() or {}).get("profile") or None

    # Open jobs only (same rule the candidate job list uses).
    jobs: dict[str, dict] = {}
    for job_document in db.collection("jobs").stream():
        job = job_document.to_dict() or {}
        if (job.get("status") or "Active") == "Active":
            jobs[job_document.id] = job

    matches: list[dict] = []

    if jobs:
        # The match document id is the candidate uid, so this is a direct
        # read per job (no collection-group index needed).
        references = [
            db.collection("jobs").document(job_id).collection("matches").document(uid)
            for job_id in jobs
        ]

        for snapshot in db.get_all(references):
            if not snapshot.exists:
                continue

            job_id = snapshot.reference.parent.parent.id
            job = jobs.get(job_id)
            if job is None:
                continue

            data = snapshot.to_dict() or {}
            try:
                match = CandidateMatch.model_validate(data)
            except Exception:
                logger.warning("Skipping unreadable match for job %s", job_id)
                continue

            scored_at = data.get("scoredAt")

            matches.append(
                {
                    "job_id": job_id,
                    "job_title": job.get("title"),
                    "department": job.get("department"),
                    "location": job.get("location"),
                    "job_type": job.get("jobType"),
                    "score": round(match.overall_score, 1),
                    "eligibility": match.eligibility,
                    "must_have_coverage": match.must_have_coverage,
                    "matched_skills": match.matched_skills,
                    "missing_skills": match.missing_skills,
                    "relevant_years": match.relevant_years,
                    "total_years": match.total_years,
                    "strengths": match.strengths,
                    "gaps": match.gaps,
                    "summary": match.summary,
                    "breakdown": match.breakdown.model_dump(),
                    "scored_at": scored_at.isoformat() if scored_at else None,
                }
            )

    matches.sort(key=lambda item: item["score"], reverse=True)

    def count(band: str) -> int:
        return sum(1 for item in matches if item["eligibility"] == band)

    scores = [item["score"] for item in matches]

    return {
        "profile": profile,
        "thresholds": {
            "highly_eligible": HIGHLY_ELIGIBLE_MIN,
            "potential": POTENTIAL_MIN,
        },
        "jobs_total": len(jobs),
        "jobs_evaluated": len(matches),
        "summary": {
            "highly_eligible": count("highly_eligible"),
            "potential": count("potential"),
            "low_match": count("low_match"),
            "average_score": round(sum(scores) / len(scores), 1) if scores else None,
            "best_score": max(scores) if scores else None,
        },
        "top_skills": _count_skills([item["matched_skills"] for item in matches]),
        "skill_gaps": _count_skills([item["missing_skills"] for item in matches]),
        "matches": matches,
    }
