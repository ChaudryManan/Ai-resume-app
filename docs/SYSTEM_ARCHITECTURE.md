# System Architecture

## Architecture Summary

The project is a Flutter client with direct Firebase and Supabase integrations, plus a separate FastAPI service. Flutter initializes Firebase and Supabase at launch. Flutter uses Firebase Authentication and Cloud Firestore directly for accounts and app data. Supabase Storage holds resume PDFs. The backend uses a Firebase service account for Firestore and Firebase ID-token verification, a Supabase server key for resume files and pgvector storage, and Gemini for profile extraction and resume embeddings.

Flutter calls `/api/resumes/embed` after a successful resume upload. `/api/resumes/screen` remains a separate backend endpoint and is not called by Flutter.

## Component Diagram

```mermaid
flowchart LR
  Candidate[Candidate Flutter UI]
  Admin[Admin Flutter UI]
  Auth[Firebase Authentication]
  DB[(Cloud Firestore)]
  Storage[(Supabase Storage: resumes)]
  Vectors[(Supabase PostgreSQL: pgvector)]
  API[FastAPI backend]
  PDF[pdfplumber]
  Gemini[Gemini API]

  Candidate -->|email/password; auth state| Auth
  Admin -->|email/password; auth state| Auth
  Candidate -->|jobs, resume metadata, applications| DB
  Admin -->|job CRUD| DB
  Candidate -->|upload/replace PDF| Storage
  Candidate -->|resume metadata| DB
  Candidate -->|Firebase ID token: POST /api/resumes/embed| API
  API -->|verify Firebase ID token| Auth
  API -->|read resumes/{uid}| DB
  API -->|download PDF| Storage
  API --> PDF
  PDF -->|extracted text| Gemini
  Gemini -->|768-dimensional chunk vectors| Vectors
  API -->|write candidate_profiles/{uid}| DB
```

The backend vector persistence is implemented through a Supabase Postgres RPC. The profile-extraction endpoint is not invoked by Flutter.

## Flutter Frontend

- `lib/main.dart` initializes `Firebase.initializeApp` using `DefaultFirebaseOptions`, initializes Supabase using `SupabaseConfig`, then renders `ResumeScreenerApp`.
- `lib/core/routing/auth_wrapper.dart` listens to Firebase auth state and loads `users/{uid}.role` through `UserService`.
- `lib/core/services/auth_service.dart` wraps email/password sign-up, login, logout, current user, auth changes, and password reset.
- Feature screens are grouped under `lib/features/auth`, `lib/features/user`, and `lib/features/admin`.
- Feature services make direct SDK calls; resume processing uses a small HTTP service for the FastAPI call.
- UI updates use `StreamBuilder` for Firestore streams and ordinary widget state for local view state.

## FastAPI Backend

`backend/app/main.py` configures Firebase Admin, Supabase, FastAPI, bearer token verification, health routes, and resume screening. It initializes Firebase from `FIREBASE_SERVICE_ACCOUNT_PATH`, accesses Firestore via the Admin SDK, and uses `SUPABASE_SECRET_KEY` server-side.

`backend/app/services/gemini_service.py` reads `GEMINI_API_KEY` and optional `GEMINI_MODEL`, calls the Google Gen AI SDK, and validates the JSON response against `CandidateProfile`.

Schemas are in `backend/app/schemas/`. `job_matching_schema.py` defines matching request/result data contracts only; no matching service or endpoint exists.

## Firebase Integration

- Firebase Authentication provides email/password accounts.
- A Firestore `users/{uid}` document stores the display name, email, role, and creation timestamp created during sign-up.
- Flutter's routing uses that Firestore role to choose the dashboard.
- FlutterFire options define Android and web configurations. The other platform branches are unsupported in the Dart options file.
- Backend Firebase Admin uses a service-account JSON file identified by an environment variable.
- Firebase configuration values exist in project configuration files. This documentation deliberately does not reproduce any key or credential values.
- No Firestore security rules file was found in the workspace. Deployed Firebase rules are not inspectable here and need verification.

## Supabase Integration

- Flutter initializes `supabase_flutter` with the project URL and publishable client key from `lib/core/supabase/supabase_config.dart`.
- The SDK's `accessToken` callback returns the current Firebase user's ID token, or `null` when signed out.
- The candidate service uploads resume bytes to the `resumes` bucket beneath a UID-prefixed path.
- The backend uses the configured Supabase URL and server secret to download the path read from Firestore.
- The backend calls the `replace_resume_embeddings` Postgres RPC. `resume_embeddings` stores chunk text, owner UID, resume path, chunk index, and a 768-dimensional vector.
- A `set_supabase_claims.py` utility sets the `role=authenticated` custom claim on all Firebase users it iterates. This is a separate administrative script, not part of app startup.
- The code uses a bucket named `resumes`; whether that bucket is private and which Storage policies are deployed cannot be verified from source. Treat as **Needs verification**.

## Gemini Integration

The backend sends extracted PDF text in a prompt to the Google Gen AI SDK. It requests JSON output matching `CandidateProfile` and uses temperature `0.1`. The model name comes from `GEMINI_MODEL`, defaulting in source to `gemini-3.5-flash-lite`. Actual model availability and deployed environment configuration need verification.

## Data Flow

### Current candidate application path

1. Firebase Auth signs the user in.
2. The app reads Firestore jobs and filters active jobs locally.
3. The app uploads a PDF to Supabase Storage.
4. The app writes resume metadata to `resumes/{uid}` in Firestore.
5. On application, the app checks that resume record and writes `applications/{uid}_{jobId}` in Firestore.

### Resume embeddings on upload

1. Flutter uploads the PDF and saves its metadata in `resumes/{uid}`.
2. Flutter calls `/api/resumes/embed` with the current Firebase ID token.
3. FastAPI verifies the token, reads `resumes/{uid}`, checks bucket/path ownership, and downloads the PDF.
4. `pdfplumber` extracts text; the backend creates overlapping chunks.
5. Gemini `gemini-embedding-001` generates 768-dimensional `RETRIEVAL_DOCUMENT` vectors.
6. A Supabase RPC replaces that user's previous vectors in `resume_embeddings`; Firestore metadata records embedding status/model/count.

The separate `/api/resumes/screen` endpoint extracts a structured profile and writes `candidate_profiles/{uid}`; it is not automatically called during upload.

## Vector Storage

The SQL migration at `supabase/migrations/20261105000000_resume_embeddings.sql` enables pgvector and creates a 768-dimension table with an HNSW cosine index, row-level security, and a service-role-only replacement RPC. Apply the migration to the same Supabase project used for Storage. The migration does not add a semantic-search endpoint.

## Runtime and Deployment Boundaries

- Backend startup fails fast if Supabase configuration, Firebase service-account path/file, or Gemini API key is missing.
- FastAPI CORS middleware accepts only origins listed in `FRONTEND_ORIGINS`; configure this for Flutter Web. No deployment manifest, Dockerfile, Firestore rules, or Supabase Storage policies were found in the reviewed workspace.
- The backend exposes FastAPI's default interactive OpenAPI UI unless disabled by the runtime configuration (no disabling configuration is present in `main.py`).
- App builds beyond Android/web Firebase configuration need setup work and verification.
