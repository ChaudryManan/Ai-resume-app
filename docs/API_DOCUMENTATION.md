# API Documentation

## Overview

The FastAPI application is defined in `backend/app/main.py`. Flutter calls the resume-embedding endpoint after upload. Firebase credentials, Supabase service configuration, and Gemini configuration are required at backend import/startup, as described in [SETUP_GUIDE.md](./SETUP_GUIDE.md).

FastAPI's generated docs are normally available at `/docs`, `/redoc`, and `/openapi.json`; these are framework-generated routes rather than explicitly declared application handlers.

## Implemented Endpoints

### `GET /`

- **Purpose:** Welcome/status response.
- **Authentication:** None.
- **Parameters/body:** None.
- **Success response (`200`):**

  ```json
  {
    "message": "Welcome to HireFlow AI Backend",
    "status": "running"
  }
  ```

- **Errors:** No explicit error handling in the route.
- **Services called:** None.
- **Source:** `home()` in `backend/app/main.py`.

### `GET /health`

- **Purpose:** Reports that backend clients were initialized during app startup.
- **Authentication:** None.
- **Parameters/body:** None.
- **Success response (`200`):**

  ```json
  {
    "status": "healthy",
    "firebase": "initialized",
    "supabase": "initialized"
  }
  ```

- **Errors:** Startup configuration errors prevent the app from loading; this handler does not check live connectivity.
- **Services called:** None at request time.
- **Source:** `health_check()` in `backend/app/main.py`.

### `GET /health/connections`

- **Purpose:** Attempts one Firestore query and a Supabase bucket listing.
- **Authentication:** None.
- **Parameters/body:** None.
- **Success response (`200`):**

  ```json
  {
    "status": "success",
    "firebase": "connected",
    "supabase": "connected"
  }
  ```

- **Error response:** HTTP `503` with a FastAPI `detail` string containing the caught exception text.
- **Services called:** `db.collection("jobs").limit(1).get()` and `supabase.storage.list_buckets()`.
- **Source:** `check_connections()` in `backend/app/main.py`.

### `POST /api/resumes/embed`

- **Purpose:** Extracts the signed-in candidate's current PDF, chunks its text, generates vector embeddings, stores the vectors in Supabase PostgreSQL, and updates Firestore processing metadata. Flutter calls this after a successful resume upload.
- **Authentication:** `Authorization: Bearer <Firebase ID token>`. The backend verifies the token and uses its UID; clients cannot choose another candidate UID.
- **Parameters/body:** No path/query parameters or request body.
- **Success response (`200`):**

  ```json
  {
    "status": "success",
    "message": "Resume embeddings generated and stored.",
    "candidate_uid": "<authenticated Firebase UID>",
    "resume_file_name": "resume.pdf",
    "total_pages": 2,
    "embedding_model": "gemini-embedding-001",
    "embedding_dimensions": 768,
    "chunks_stored": 4
  }
  ```

- **Errors:** `401` for invalid/expired Firebase ID token; `404` for missing resume metadata; `400` for invalid storage metadata or PDF; `403` for a path not owned by the authenticated user; `422` for no readable PDF text; `500` for Gemini, Supabase RPC, or unexpected processing failures.
- **Services/functions called:** `_read_resume_text()`, `chunk_resume_text()`, `embed_resume_chunks()`, Firebase Admin, Supabase Storage, Gemini `gemini-embedding-001`, and Supabase RPC `replace_resume_embeddings`.
- **Data written:** Supabase `public.resume_embeddings` replaces prior vector rows for that user; `resumes/{uid}` in Firestore records embedding status, model, dimension, chunk count, and timestamp.
- **Source:** `embed_resume()` in `backend/app/main.py`.

### `POST /api/resumes/screen`

- **Purpose:** Downloads the authenticated user's stored resume, extracts PDF text, asks Gemini for a structured profile, saves it, and returns it.
- **Authentication:** `HTTPBearer`; `get_current_user` calls Firebase Admin `auth.verify_id_token`. Invalid/expired token handling is HTTP `401`. A missing bearer token is handled by FastAPI's security dependency; verify exact response under the installed FastAPI version.
- **Parameters/body:** No path/query parameters and no request body. The caller must send a Firebase ID token in the `Authorization: Bearer ...` header.
- **Success response (`200`):**

  ```json
  {
    "status": "success",
    "message": "Resume screened successfully by gemini.",
    "candidate_uid": "<authenticated Firebase UID>",
    "file_name": "<stored filename>",
    "total_pages": 1,
    "characters_extracted": 1234,
    "candidate_profile": {
      "full_name": null,
      "professional_title": null,
      "email": null,
      "phone": null,
      "location": null,
      "professional_summary": null,
      "education": [],
      "total_experience": null,
      "work_experience": [],
      "technical_skills": [],
      "certifications": [],
      "projects": [],
      "languages": []
    }
  }
  ```

  The profile values above illustrate the actual Pydantic output shape and default empty/null values, not a guaranteed extraction result.

- **Document written:** `candidate_profiles/{uid}` with UID, resume name/path, `"completed"` screening status, profile map, and server timestamp.
- **Services/functions called:** Firebase token verification; Firestore `resumes/{uid}` read and `candidate_profiles/{uid}` merge-write; Supabase Storage download; `pdfplumber`; `extract_candidate_profile()` in `backend/app/services/gemini_service.py`.
- **Validation checks in code:** Resume document exists, metadata present, `bucket == "resumes"`, path starts with `{uid}/`, file non-empty, `%PDF-` signature, and extracted text non-empty.
- **Error behavior:** In-route `HTTPException`s preserve their status. Unexpected processing errors return HTTP `500` with generic detail `"An error occurred while processing the resume."` Errors from the authentication dependency occur before entering this route and are handled separately.
- **Source:** `screen_resume()` in `backend/app/main.py`.

## Planned / Missing API Endpoints

No endpoint exists in the source for:

- Vector similarity search or candidate/job matching/ranking.
- Admin retrieval/review/update of real candidate applications.
- Candidate selection persistence.
- Personalized offer generation.
- Offer approval or delivery.
- Candidate offer viewing or response.

The Pydantic models in `backend/app/schemas/job_matching_schema.py` are not API endpoints.
