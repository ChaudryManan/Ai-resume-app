import logging

from fastapi import APIRouter, BackgroundTasks, Depends, HTTPException
from firebase_admin import firestore

from app.services.gemini_service import (
    EMBEDDING_DIMENSIONS,
    EMBEDDING_MODEL,
    build_job_matching_chunks,
    embed_resume_chunks,
)
from app.dependencies.auth import require_admin
from app.services.job_embedding_service import build_job_profile
from app.services.matching_service import run_matching_in_background
from app.services.supabase_client import get_supabase as _supabase

logger = logging.getLogger(__name__)

router = APIRouter(tags=["jobs"])


def _set_status(job_ref, status: str) -> None:
    try:
        job_ref.set({"embeddingStatus": status}, merge=True)
    except Exception as error:
        logger.error(
            "Could not update job embedding status: %s",
            type(error).__name__,
        )


@router.post("/api/jobs/{job_id}/embed")
def embed_job(
    job_id: str,
    background_tasks: BackgroundTasks,
    match: bool = True,
    admin: dict = Depends(require_admin),
):
    job_ref = None

    try:
        # STEP 1: Fetch the job created by the admin from Firestore
        job_ref = firestore.client().collection("jobs").document(job_id)
        job_snapshot = job_ref.get()

        if not job_snapshot.exists:
            job_ref = None
            raise HTTPException(status_code=404, detail="Job not found.")

        job = job_snapshot.to_dict() or {}
        job_ref.set({"embeddingStatus": "processing"}, merge=True)

        # STEP 2: Convert the job into the same profile shape as a resume
        # (CandidateProfile) and save it, like candidate_profiles/{uid}.
        profile_data = build_job_profile(job).model_dump()

        firestore.client().collection("job_profiles").document(job_id).set(
            {
                "job_id": job_id,
                "profile": profile_data,
                "profileBuiltAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        # Build chunks with the SAME function used for resumes
        chunks = build_job_matching_chunks(profile_data)
        if not chunks:
            raise HTTPException(
                status_code=422,
                detail="Job has no content to embed.",
            )

        # STEP 3: Generate vectors with Gemini
        vectors = embed_resume_chunks(chunks)
        if len(vectors) != len(chunks):
            raise ValueError("Number of embeddings does not match chunks.")

        # STEP 4: Store vectors in Supabase
        chunk_records = [
            {"chunk_index": index, "content": chunk, "embedding": vector}
            for index, (chunk, vector) in enumerate(zip(chunks, vectors))
        ]

        _supabase().rpc(
            "replace_job_embeddings",
            {"p_job_id": job_id, "p_chunks": chunk_records},
        ).execute()

        # STEP 5: Record success on the Firestore job document
        job_ref.set(
            {
                "embeddingStatus": "completed",
                "embeddingModel": EMBEDDING_MODEL,
                "embeddingDimensions": EMBEDDING_DIMENSIONS,
                "embeddingChunkCount": len(chunk_records),
                "embeddedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        # STEP 6: Match the new job with all screened resumes in the background
        if match:
            background_tasks.add_task(run_matching_in_background, job_id)

        return {
            "status": "success",
            "message": "Job embeddings generated.",
            "matching": "started" if match else "skipped",
            "job_id": job_id,
            "embedding_model": EMBEDDING_MODEL,
            "embedding_dimensions": EMBEDDING_DIMENSIONS,
            "chunks_stored": len(chunk_records),
            "embedded_sections": [
                chunk.split(":", 1)[0] for chunk in chunks
            ],
        }

    except HTTPException as error:
        logger.warning(
            "Job embedding rejected for job %s: %s %s",
            job_id,
            error.status_code,
            error.detail,
        )
        if job_ref is not None:
            _set_status(job_ref, "failed")
        raise

    except Exception as error:
        if job_ref is not None:
            _set_status(job_ref, "failed")
        logger.exception("Job embedding failed for job: %s", job_id)
        raise HTTPException(
            status_code=500,
            detail="Error generating job embeddings.",
        ) from error
