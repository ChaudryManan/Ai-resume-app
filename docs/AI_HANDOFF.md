# AI Developer Handoff

## 1. What This Project Is

This repository contains a Flutter recruitment app, Firebase Authentication/Firestore integration, Supabase resume storage and pgvector persistence, and a separate FastAPI backend for Gemini resume processing. The implemented product supports candidate registration, active-job browsing, resume upload, upload-triggered resume embeddings, application submission, and admin job CRUD. Profile screening is available through the backend but is not part of the upload flow; matching, ranking, offer generation, approval, and delivery are not implemented.

The Flutter UI calls itself *HireFlow* in candidate screens and *Resume Screener* in app metadata. The user-provided project name is **AI-Powered Resume Screener and Recruitment Management System**.

## 2. How the System Works

The Flutter app initializes Firebase and Supabase in `lib/main.dart`. Firebase Auth state controls the app root. For signed-in users, `AuthWrapper` reads `users/{uid}.role` and routes to admin or candidate screens. Flutter features access Firestore directly through feature services. Resume bytes go to Supabase Storage; the matching Firestore metadata is stored under the candidate UID.

After a resume upload, Flutter calls `POST /api/resumes/embed` with the signed-in user's Firebase ID token. FastAPI verifies that token, reads the caller's resume metadata, downloads the PDF using the server-side Supabase key, extracts text with `pdfplumber`, chunks it, requests document embeddings from Gemini, and stores the vectors in Supabase pgvector. It updates embedding status and metadata in `resumes/{uid}` in Firestore. A separate `POST /api/resumes/screen` route extracts a JSON candidate profile with Gemini and writes `candidate_profiles/{uid}`, but Flutter does not currently invoke that route.

## 3. Folder Structure

Relevant source and configuration (generated build output omitted):

```text
resume_screener/
  lib/
    main.dart
    core/
      firebase/firebase_options.dart
      routing/auth_wrapper.dart
      services/auth_service.dart
      supabase/supabase_config.dart
      network/api_config.dart
      theme/app_theme.dart
    features/
      auth/
        screens/login_screen.dart
        screens/signup_screen.dart
        services/user_service.dart
        widgets/auth_page_shell.dart
        widgets/auth_primary_button.dart
        widgets/auth_text_field.dart
      user/
        screens/user_dashboard.dart
        services/user_job_service.dart
        services/resume_processing_service.dart
      admin/
        screens/admin_dashboard.dart
        screens/analytics_screen.dart
        screens/candidates_screen.dart
        screens/create_job_screen.dart
        screens/manage_jobs_screen.dart
        screens/overview_screen.dart
        screens/settings_screen.dart
        services/admin_service.dart
        widgets/admin_sidebar.dart
        widgets/admin_topbar.dart
  backend/
    .env                         # Exists locally; never publish its contents
    requirements.txt
    app/
      main.py
      routers/matching.py           # Entire file is commented-out prototype
      schemas/job_matching_schema.py
      schemas/resume_schema.py
      services/gemini_service.py
      services/resume_embedding_service.py
      services/embedding_service.py # Entire file is commented-out prototype
    tests/test_resume_embedding_service.py
  supabase/
    migrations/20261105000000_resume_embeddings.sql
  test/widget_test.dart
  android/, ios/, linux/, macos/, web/, windows/
  pubspec.yaml
  pubspec.lock
  firebase.json
  analysis_options.yaml
  set_supabase_claims.py
  admin_dashboard_backup.txt     # Backup snapshot, not imported by the app
  README.md
  docs/                          # Project handoff documentation
  .github/copilot-instructions.md
```

No matching/offer services, Firestore rules, or Supabase Storage policy files were found. Backend unit tests currently cover chunking only.

## 4. Technologies and Dependencies

- Flutter/Dart (`pubspec.yaml` SDK constraint: `^3.11.0`).
- Firebase Core, Firebase Auth, Cloud Firestore, Firebase Storage dependency (unused in app source).
- `supabase_flutter`, `file_picker`.
- Flutter `http` client calls the embedding API after successful upload.
- Python: FastAPI, Uvicorn, `python-dotenv`, `supabase`, `firebase-admin`, `pdfplumber`, `pydantic`, `google-genai`.
- `openai` appears in backend requirements but is not used by inspected backend source.
- No Python dependency versions or Python runtime are pinned.

## 5. Frontend Architecture

- App bootstrap: `lib/main.dart`.
- Session/role route: `lib/core/routing/auth_wrapper.dart`.
- Auth operations: `lib/core/services/auth_service.dart`.
- User data and role read: `lib/features/auth/services/user_service.dart`.
- Candidate jobs/resume/applications: `lib/features/user/services/user_job_service.dart` and `lib/features/user/screens/user_dashboard.dart`.
- Admin jobs: `lib/features/admin/services/admin_service.dart`; screens under `lib/features/admin/screens/`.
- UI uses `StatefulWidget`, local state, Firestore streams, and Material widgets. A small `http` client service is used for resume processing; no broader state-management library is declared.
- Candidate UI only shows active jobs, supports title/department/location search, resume upload/replace, and apply once per job.
- After upload, Flutter obtains a Firebase ID token and calls `POST /api/resumes/embed`; base URL comes from `--dart-define=API_BASE_URL=...`.
- Admin job create/edit/close/delete is wired. Candidate list and analytics pages are demo-only.

## 6. Backend Architecture

- All routes and Firebase/Supabase initialization are in `backend/app/main.py`.
- `get_current_user` verifies bearer Firebase ID tokens.
- `backend/app/services/gemini_service.py` makes a Gemini structured-output request.
- The same Gemini client generates 768-dimensional resume chunk embeddings using `gemini-embedding-001`.
- `backend/app/services/resume_embedding_service.py` chunks resume text (1,800 characters max, 200 overlap).
- `backend/app/schemas/resume_schema.py` defines profile response shape.
- `backend/app/schemas/job_matching_schema.py` contains unimplemented matching contracts. `routers/matching.py` and `services/embedding_service.py` are commented-out prototypes, not active code.
- `supabase/migrations/20261105000000_resume_embeddings.sql` defines the pgvector table and backend RPC; it must be applied to the Supabase project.
- Backend settings: `SUPABASE_URL`, `SUPABASE_SECRET_KEY`, `FIREBASE_SERVICE_ACCOUNT_PATH`, `GEMINI_API_KEY`, optional `GEMINI_MODEL`.

## 7. Database and Storage Schema

See [DATABASE_SCHEMA.md](./DATABASE_SCHEMA.md) for exact fields. Summary:

- `users/{uid}` — identity/profile/role.
- `jobs/{autoId}` — job posting.
- `resumes/{uid}` — current resume metadata; object is in Supabase.
- `resumes/{uid}` also tracks embedding status/model/dimensions/chunk count/timestamp.
- Supabase `public.resume_embeddings` — one row per resume chunk, holding UID, current path, chunk text and vector(768).
- `applications/{uid}_{jobId}` — candidate/job application and copied resume/job metadata.
- `candidate_profiles/{uid}` — backend-generated `CandidateProfile`.
- Supabase `resumes/{uid}/{timestamp}_{filename}` — PDF object.

Firestore rules and Supabase bucket policies are absent from this workspace; deployed settings need verification.

## 8. Authentication and Authorization

Firebase email/password auth is implemented. Sign-up writes role `"user"`. `AuthWrapper` routes based on a Firestore role. There is no admin provisioning UI, and role routing is not authorization. FastAPI verifies identity but does not verify an admin role. Do not add privileged workflows without checking/enforcing deployed rules and server-side authorization.

Important sensitive items:

- `login_screen.dart` currently prints a Firebase ID token.
- `backend/.env` exists locally; its contents must stay private.
- `backend/.gitignore` ignores `backend/.env`; verify it remains untracked. The root `.gitignore` has no general `.env` rule for other locations.
- `set_supabase_claims.py` uses a machine-specific credential file path and updates claims for all enumerated users.

Never copy actual key/token/credential values into code, docs, chat, logs, or commits.

## 9. Implemented API

`backend/app/main.py` defines:

- `GET /` — welcome response.
- `GET /health` — startup initialization status, not a live check.
- `GET /health/connections` — unauthenticated Firestore/Supabase connectivity attempt.
- `POST /api/resumes/embed` — authenticated upload-triggered PDF chunk embedding and Supabase pgvector storage.
- `POST /api/resumes/screen` — authenticated PDF profile extraction; no body, Firebase bearer token required.

Full request/response and error details are in [API_DOCUMENTATION.md](./API_DOCUMENTATION.md). No vector similarity search, application-review, or offer endpoints exist.

## 10. AI Processing Pipeline

The upload path invokes `/api/resumes/embed`: the backend retrieves the candidate's Supabase PDF, validates `%PDF-`, extracts text with `pdfplumber`, chunks it with overlap, generates Gemini `gemini-embedding-001` retrieval-document embeddings, and stores them through a Supabase Postgres RPC. The pgvector table is 768 dimensions and the migration must be applied. Firestore records embedding status. `API_BASE_URL` must be configured at Flutter launch/build time.

Separately, `/api/resumes/screen` extracts a structured `CandidateProfile` with the Gemini generation model and writes `candidate_profiles/{uid}`; Flutter does not invoke that endpoint.

No matching calculation, score weighting, ranking, candidate selection AI, personalized offer generation, approval, or delivery is implemented. Demo scores on the admin candidate screen are not AI output.

## 11. Completed and Incomplete Features

**Working implementation paths:** Firebase email/password auth, client role routing, user Firestore profile, admin job CRUD, candidate job listing/search, resume upload/replacement, application record creation, and resume embedding call/storage code (pending migration/API setup).

**Partial or demo-only:** Firestore-role routing without checked-in rules; candidate dashboard status display; profile extraction not connected to Flutter; embedding runtime setup pending; admin dashboard metrics; admin candidate list; analytics; company/notification settings.

**Missing:** vector similarity search, job-description embeddings, matching/ranking algorithm, real candidate review, offer generation/approval/delivery, admin provisioning, OCR, and Firestore/Supabase Storage policies in repository.

Use [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) for status/evidence per feature.

## 12. Known Issues and Current Development State

- Login logs the Firebase ID token.
- A starter counter widget test does not match the app and pumps the app without the main Firebase/Supabase bootstrap; its runtime outcome has not been verified.
- Profile-screening endpoint is not called by Flutter; the separate embedding endpoint is called after upload.
- Static candidate/analytics data can be mistaken for real data if not labeled.
- Admin overview's candidate/review metrics are fixed at zero.
- Admin navigation hides the sidebar below 850 px without a narrow-screen navigation alternative; overview also reads an `applicants` field that job creation does not write, so it defaults to zero.
- `backend/.env` is ignored by its local `.gitignore`; verify it remains untracked.
- Backend unit tests only cover chunking; no rules files or Python pin/lock file are present.
- Gemini model availability and deployed bucket/rules configuration are unknown.

**Current state:** functional app skeleton with live auth, job CRUD, resume storage, applications, and upload-triggered embedding code. The pgvector schema and backend integration need deployment/configuration verification; semantic search and recruitment automation remain incomplete.

## 13. Exact Next Development Task

**First task: apply `supabase/migrations/20261105000000_resume_embeddings.sql`, configure `API_BASE_URL` and Gemini embedding access, and smoke-test upload-to-`resume_embeddings` end to end.** Verify that replacement removes stale vectors and that a failed embedding leaves `embeddingStatus=failed`. Then define and verify least-privilege Firestore and Supabase Storage policies before adding semantic search.

After that, remove token logging and `.env` exposure risk, fix/test backend error mapping, and integrate the screening endpoint from Flutter.

## 14. Coding Conventions and Change Map

Follow observed style: Dart files grouped by feature and use lower_snake_case filenames; classes/types in UpperCamelCase; services are small classes wrapping SDK calls. Python uses snake_case functions, Pydantic schemas, and environment-driven backend configuration. Keep secrets out of code. The app now uses a small `http` service for resume processing; no broader state-management pattern is present.

| Feature/change | Existing integration points |
|---|---|
| Auth screens/operations | `lib/features/auth/screens/`, `lib/core/services/auth_service.dart` |
| Role lookup/routing | `lib/core/routing/auth_wrapper.dart`, `lib/features/auth/services/user_service.dart` |
| Candidate job/resume/application UI | `lib/features/user/screens/user_dashboard.dart`, `lib/features/user/services/user_job_service.dart` |
| Resume vector API client | `lib/core/network/api_config.dart`, `lib/features/user/services/resume_processing_service.dart`, and the upload call in `user_dashboard.dart` |
| Admin job operations | `lib/features/admin/screens/create_job_screen.dart`, `manage_jobs_screen.dart`, `overview_screen.dart`; `lib/features/admin/services/admin_service.dart` |
| Real candidate review | Replace demo logic in `lib/features/admin/screens/candidates_screen.dart`; define backend/Firestore contract and access policy first |
| Resume vector generation/storage | `backend/app/main.py`, `backend/app/services/gemini_service.py`, `backend/app/services/resume_embedding_service.py`, `supabase/migrations/20261105000000_resume_embeddings.sql` |
| Profile extraction changes | `backend/app/main.py`, `backend/app/services/gemini_service.py`, `backend/app/schemas/resume_schema.py` |
| Matching implementation | Add an appropriately scoped vector-search service/route and tests; existing contract is `backend/app/schemas/job_matching_schema.py` |
| Offer workflow | Requires new explicit schemas/service/routes and app screens; no existing implementation to duplicate |
| Firebase/Supabase configuration | `lib/core/firebase/firebase_options.dart`, `lib/core/supabase/supabase_config.dart`, `firebase.json`, and external console policies |

Do not infer that a screen or schema means its integration is complete.

## 15. Testing and Verification

Frontend:

```powershell
flutter pub get
flutter analyze
flutter test
```

Backend, from `backend` with the configured environment:

```powershell
python -m compileall app
python -m unittest discover -s tests -v
uvicorn app.main:app --reload --host 0.0.0.0
```

Test `GET /health`, `GET /health/connections`, `POST /api/resumes/embed`, and `POST /api/resumes/screen` only with safe local configuration and test accounts/data. Unit tests currently cover chunking only. Add API tests for auth failure, owner mismatch, invalid/empty/scanned PDF, Gemini failure, RPC failure, and success. Verify policies using Firebase/Supabase test tooling before production.

## INSTRUCTIONS FOR THE NEXT AI DEVELOPER

- Read AI_HANDOFF.md first.
- Then read PROJECT_OVERVIEW.md, SYSTEM_ARCHITECTURE.md, PROJECT_FLOW.md, DATABASE_SCHEMA.md, API_DOCUMENTATION.md, and IMPLEMENTATION_STATUS.md.
- Inspect the actual source files before making changes.
- Never rewrite working code unnecessarily.
- Preserve the existing architecture and naming conventions.
- Never introduce duplicate services, models, or API endpoints.
- Make changes incrementally.
- Provide complete code with exact file paths when implementing features.
- Explain dependencies and integration steps.
- Test existing functionality after modifications.
- Update documentation whenever implementation changes.
