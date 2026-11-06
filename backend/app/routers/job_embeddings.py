import logging
import os
from functools import lru_cache

from fastapi import APIRouter, Depends, HTTPException
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from firebase_admin import auth, firestore
from supabase import Client, create_client

from app.services.gemini_service import (
    EMBEDDING_DIMENSIONS,
    EMBEDDING_MODEL,
    embed_resume_chunks,
)
from app.services.job_embedding_service import build_job_chunks

logger = logging.getLogger(__name__)

router = APIRouter(tags=["jobs"])
bearer = HTTPBearer()


@lru_cache(maxsize=1)
def _supabase() -> Client:
    return create_client(
        os.environ["SUPABASE_URL"],
        os.environ["SUPABASE_SECRET_KEY"],
    )


def _require_admin(
    credentials: HTTPAuthorizationCredentials = Depends(bearer),
) -> dict:
    try:
        decoded = auth.verify_id_token(credentials.credentials)
    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Firebase token.",
        )

    snapshot = (
        firestore.client().collection("users").document(decoded["uid"]).get()
    )
    role = (snapshot.to_dict() or {}).get("role") if snapshot.exists else None

    if role != "admin":
        raise HTTPException(status_code=403, detail="Admin access required.")

    return decoded


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
    admin: dict = Depends(_require_admin),
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

        # STEP 2: Build text chunks from the job fields
        chunks = build_job_chunks(job)
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

        return {
            "status": "success",
            "message": "Job embeddings generated.",
            "job_id": job_id,
            "embedding_model": EMBEDDING_MODEL,
            "embedding_dimensions": EMBEDDING_DIMENSIONS,
            "chunks_stored": len(chunk_records),
        }

    except HTTPException:
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
