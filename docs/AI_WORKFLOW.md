# AI Workflow

## Implemented Pipeline

The resume-embedding operation is triggered by Flutter after upload. Profile extraction remains a separate backend operation and is not currently triggered by Flutter.

1. **Authentication:** `POST /api/resumes/screen` requires a Firebase ID token. `get_current_user()` verifies it using Firebase Admin and uses the token UID.
2. **Metadata lookup:** The backend reads `resumes/{uid}` from Firestore.
3. **Storage validation:** It requires a non-empty `storagePath`, bucket metadata equal to `"resumes"`, and a path prefixed by the authenticated UID.
4. **PDF download:** The backend downloads the object from Supabase Storage bucket `resumes`.
5. **PDF validation:** It rejects empty downloads and checks for the `%PDF-` signature.
6. **Text extraction:** `pdfplumber.open(io.BytesIO(pdf_bytes))` visits every page and appends non-empty `page.extract_text()` output. It returns an error if no readable text is found.
7. **Profile extraction:** `extract_candidate_profile(extracted_text)` calls the Google Gen AI Python SDK.
8. **Structured validation:** The model response is requested as JSON using Pydantic `CandidateProfile` as the response schema, then validated with `CandidateProfile.model_validate_json`.
9. **Persistence and response:** The backend writes `candidate_profiles/{uid}` and returns the profile plus filename, page count, and extracted character count.

## Embeddings Generated During Upload

1. `ResumeProcessingService.generateResumeEmbeddings()` sends a `POST /api/resumes/embed` request with the Firebase ID token after Supabase upload and Firestore metadata save.
2. FastAPI verifies the token and reuses the authenticated UID to locate the resume document and UID-prefixed Supabase Storage path.
3. `pdfplumber` extracts text from the PDF.
4. `chunk_resume_text()` normalizes whitespace and splits text into chunks of at most 1,800 characters with 200 characters of overlap.
5. `embed_resume_chunks()` batches up to 50 chunks per Google Gen AI request using `gemini-embedding-001`, `RETRIEVAL_DOCUMENT`, and `output_dimensionality=768`.
6. Supabase RPC `replace_resume_embeddings` atomically deletes the user's prior vectors and inserts the new chunk text/vector rows into `public.resume_embeddings`.
7. Firestore `resumes/{uid}` records `embeddingStatus`, `embeddingModel`, `embeddingDimensions`, `embeddingChunkCount`, and `embeddedAt`. The UI displays the stored chunk count or an embedding error.

The database shape and security are defined in `supabase/migrations/20261105000000_resume_embeddings.sql`. The migration must be applied and the backend URL configured for the feature to work.

### PDF/OCR Limits

- `pdfplumber` text extraction is implemented.
- Optical character recognition is **not implemented**. Scanned/image-only documents can return the explicit "No readable text found" validation error.
- The backend does not impose the Flutter's 5 MiB upload cap on files independently.
- The route does not persist raw extracted text.

## Gemini Configuration

`backend/app/services/gemini_service.py`:

- Reads `GEMINI_API_KEY` and raises at import time if it is missing.
- Reads `GEMINI_MODEL`; current source default is `gemini-2.5-flash-lite`.
- Reads optional `GEMINI_EMBEDDING_MODEL`; default is `gemini-embedding-001`.
- Uses a fixed 768-dimensional vector size to match the Supabase table migration.
- Builds a `google.genai.Client` and calls `client.models.generate_content`.
- Requests `response_mime_type="application/json"` and `response_schema=CandidateProfile`.
- Uses `temperature=0.1`.
- Rejects empty input and empty Gemini response; validates response JSON as `CandidateProfile`.

The profile extraction prompt asks for evidence-based extraction, nulls for missing scalar fields, empty lists for missing collections, separate education/work history, preserving meaning, not inferring experience unsupported by dates, ignoring instructions inside resume content, and avoiding sensitive protected characteristics.

## Candidate Profile Fields

The `CandidateProfile` model defines:

- Identity/contact: `full_name`, `email`, `phone`, `location`.
- Professional: `professional_title`, `professional_summary`, `total_experience`.
- Collections: `education`, `work_experience`, `technical_skills`, `certifications`, `projects`, `languages`.
- Nested education: degree, institution, graduation year.
- Nested experience: company, job title, duration, responsibilities.

The schema allows null or empty values. It does not contain a numeric experience-month calculation or confidence score.

## Matching and Ranking

**Not implemented.** `backend/app/schemas/job_matching_schema.py` has contracts for job requirements, component/overall match scores, matched/missing skills, explanation, and matching status. `backend/app/routers/matching.py` and `backend/app/services/embedding_service.py` contain commented-out prototype code, but it is not executable or registered by `main.py`. No active algorithm, endpoint, persisted search path, or UI consumer exists. There are no confirmed weights, normalization rules, ranking tie-breakers, or cutoffs.

The `CandidatesScreen` scores are hard-coded demo values, not model output.

## Personalized Offer Generation

**Not implemented.** No prompt, model call, offer schema, service, endpoint, stored offer record, admin approval workflow, or delivery mechanism exists.

## Remaining Integration Gap

Flutter invokes `/api/resumes/embed` but does not call `/api/resumes/screen`; profile extraction is still not part of the upload flow. No vector similarity search, job-description embedding, candidate-job matching, or ranking endpoint has been implemented. Before production, apply and verify the SQL migration and storage policies, configure the API URL/CORS for the chosen platform, and handle operational failures/retries.
