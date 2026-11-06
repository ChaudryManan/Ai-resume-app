
import os
import io
import logging

import firebase_admin
import pdfplumber

from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from firebase_admin import credentials, firestore, auth
from supabase import create_client, Client
# Load environment variables before importing gemini service
load_dotenv()

from app.services.gemini_service import (
    EMBEDDING_DIMENSIONS,
    EMBEDDING_MODEL,
    embed_resume_chunks,
    extract_candidate_profile,
    build_job_matching_chunks
)
from app.services.resume_embedding_service import chunk_resume_text

# --------------------------------------------------
# 1. Environment variables
# --------------------------------------------------

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY")

FIREBASE_SERVICE_ACCOUNT_PATH = os.getenv(
    "FIREBASE_SERVICE_ACCOUNT_PATH"
)

if not SUPABASE_URL or not SUPABASE_SECRET_KEY:
    raise RuntimeError("Supabase configuration is missing.")

if not FIREBASE_SERVICE_ACCOUNT_PATH:
    raise RuntimeError("Firebase service account path is missing.")

if not os.path.isfile(FIREBASE_SERVICE_ACCOUNT_PATH):
    raise RuntimeError("Firebase service account JSON was not found.")


# --------------------------------------------------
# 2. Initialize Firebase
# --------------------------------------------------

if not firebase_admin._apps:
    firebase_credential = credentials.Certificate(
        FIREBASE_SERVICE_ACCOUNT_PATH
    )

    firebase_admin.initialize_app(firebase_credential)

db = firestore.client()


# --------------------------------------------------
# 3. Initialize Supabase
# --------------------------------------------------

supabase: Client = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)


# --------------------------------------------------
# 4. FastAPI application
# --------------------------------------------------

app = FastAPI(
    title="HireFlow AI Resume Screening API",
    description="Backend for AI-powered resume screening and job matching.",
    version="1.0.0"
)

cors_origins = [
    origin.strip()
    for origin in os.getenv("FRONTEND_ORIGINS", "").split(",")
    if origin.strip()
]

if cors_origins:
    app.add_middleware(
        CORSMiddleware,
        allow_origins=cors_origins,
        allow_credentials=False,
        allow_methods=["GET", "POST"],
        allow_headers=["Authorization", "Content-Type"],
    )

security = HTTPBearer()
logger = logging.getLogger(__name__)


# --------------------------------------------------
# 5. Verify Firebase authentication
# --------------------------------------------------

def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    token = credentials.credentials

    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token

    except Exception:
        raise HTTPException(
            status_code=401,
            detail="Invalid or expired Firebase token."
        )


# --------------------------------------------------
# 6. Welcome endpoint
# --------------------------------------------------

@app.get("/")
def home():
    return {
        "message": "Welcome to HireFlow AI Backend",
        "status": "running"
    }


# --------------------------------------------------
# 7. Health endpoint
# --------------------------------------------------

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "firebase": "initialized",
        "supabase": "initialized"
    }


# --------------------------------------------------
# 8. Connection test
# --------------------------------------------------

@app.get("/health/connections")
def check_connections():

    try:
        db.collection("jobs").limit(1).get()
        supabase.storage.list_buckets()

        return {
            "status": "success",
            "firebase": "connected",
            "supabase": "connected"
        }

    except Exception as error:
        raise HTTPException(
            status_code=503,
            detail=f"Connection test failed: {str(error)}"
        )


# --------------------------------------------------
# 9. Resume text extraction
# --------------------------------------------------

def _read_resume_text(uid: str):
    resume_ref = db.collection("resumes").document(uid)
    resume_snapshot = resume_ref.get()

    if not resume_snapshot.exists:
        raise HTTPException(
            status_code=404,
            detail="No resume found for this candidate.",
        )

    resume_data = resume_snapshot.to_dict()
    if not resume_data:
        raise HTTPException(
            status_code=404,
            detail="Resume information is empty.",
        )

    storage_path = resume_data.get("storagePath")
    bucket_name = resume_data.get("bucket")

    if not storage_path or bucket_name != "resumes":
        raise HTTPException(
            status_code=400,
            detail="Invalid resume storage information.",
        )

    if not storage_path.startswith(f"{uid}/"):
        raise HTTPException(
            status_code=403,
            detail="Invalid resume ownership.",
        )

    pdf_bytes = supabase.storage.from_("resumes").download(storage_path)
    if not pdf_bytes:
        raise HTTPException(
            status_code=400,
            detail="Downloaded resume is empty.",
        )

    if not pdf_bytes.startswith(b"%PDF-"):
        raise HTTPException(
            status_code=400,
            detail="The uploaded file is not a valid PDF.",
        )

    with pdfplumber.open(io.BytesIO(pdf_bytes)) as pdf:
        total_pages = len(pdf.pages)
        extracted_text = "\n".join(
            page_text
            for page in pdf.pages
            if (page_text := page.extract_text())
        ).strip()

    if not extracted_text:
        raise HTTPException(
            status_code=422,
            detail=(
                "No readable text found. "
                "This may be a scanned PDF requiring OCR."
            ),
        )

    return resume_ref, resume_data, storage_path, total_pages, extracted_text


@app.post("/api/resumes/screen")
def screen_resume(
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]

    try:
        _, resume_data, storage_path, total_pages, extracted_text = (
            _read_resume_text(uid)
        )
        profile = extract_candidate_profile(extracted_text)
        profile_data = profile.model_dump()

        db.collection("candidate_profiles").document(uid).set(
            {
                "uid": uid,
                "resumeFileName": resume_data.get("fileName"),
                "resumeStoragePath": storage_path,
                "screening_status": "completed",
                "profile": profile_data,
                "screenedAt": firestore.SERVER_TIMESTAMP,
            },
            merge=True,
        )

        return {
            "status": "success",
            "message": "Resume screened successfully by Gemini.",
            "candidate_uid": uid,
            "file_name": resume_data.get("fileName"),
            "total_pages": total_pages,
            "characters_extracted": len(extracted_text),
            "candidate_profile": profile_data,
        }
    except HTTPException:
        raise
    except Exception as error:
        logger.error(
            "Resume screening failed: %s",
            type(error).__name__,
        )
        raise HTTPException(
            status_code=500,
            detail="An error occurred while processing the resume.",
        ) from error


def _set_embedding_status(resume_ref, status: str) -> None:
    try:
        resume_ref.set({"embeddingStatus": status}, merge=True)
    except Exception as error:
        logger.error(
            "Could not update resume embedding status: %s",
            type(error).__name__,
        )



@app.post("/api/resumes/embed")
def embed_resume(
    current_user: dict = Depends(get_current_user),
):
    uid = current_user["uid"]
    resume_ref = None

    try:
        # STEP 1: Get screened candidate profile
        profile_ref = (
            db.collection("candidate_profiles").document(uid)
        )

        profile_snapshot = profile_ref.get()

        if not profile_snapshot.exists:
            raise HTTPException(
                status_code=404,
                detail="Please screen your resume first.",
            )

        candidate_data = profile_snapshot.to_dict()

        profile = candidate_data.get("profile")

        if not profile:
            raise HTTPException(
                status_code=422,
                detail="Candidate profile is empty.",
            )

        # STEP 2: Get resume document
        resume_ref = db.collection("resumes").document(uid)

        resume_snapshot = resume_ref.get()

        if not resume_snapshot.exists:
            raise HTTPException(
                status_code=404,
                detail="Resume document not found.",
            )

        resume_ref.set(
            {"embeddingStatus": "processing"},
            merge=True,
        )

        # STEP 3: Build job-matching chunks
        chunks = build_job_matching_chunks(profile)

        if not chunks:
            raise HTTPException(
                status_code=422,
                detail="No job-relevant information found.",
            )

        # STEP 4: Generate vectors
        vectors = embed_resume_chunks(chunks)

        if len(vectors) != len(chunks):
            raise ValueError(
                "Number of embeddings does not match chunks."
            )

        # STEP 5: Prepare records for Supabase
        chunk_records = [
            {
                "chunk_index": index,
                "content": chunk,
                "embedding": vector,
            }
            for index, (chunk, vector) in enumerate(
                zip(chunks, vectors)
            )
        ]

        # STEP 6: Store vectors in Supabase
        supabase.rpc(
            "replace_resume_embeddings",
            {
                "p_user_id": uid,
                "p_resume_path": candidate_data.get(
                    "resumeStoragePath"
                ),
                "p_chunks": chunk_records,
            },
        ).execute()

        # STEP 7: Update Firestore status
        resume_ref.set(
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
            "message": "Candidate job-matching embeddings generated.",
            "candidate_uid": uid,
            "embedding_model": EMBEDDING_MODEL,
            "embedding_dimensions": EMBEDDING_DIMENSIONS,
            "chunks_stored": len(chunk_records),
            "embedded_sections": [
                "professional_profile",
                "technical_skills",
                "total_experience",
                "work_experience",
                "education",
                "certifications",
                "languages",
                "projects",
            ],
        }

    except HTTPException:
        if resume_ref is not None:
            _set_embedding_status(resume_ref, "failed")
        raise

    except Exception as error:
        if resume_ref is not None:
            _set_embedding_status(resume_ref, "failed")

        logger.exception(
            "Candidate embedding failed for UID: %s", uid
        )

        raise HTTPException(
            status_code=500,
            detail="Error generating candidate embeddings.",
        ) from error
