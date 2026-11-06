# Implementation Status

Statuses reflect source code found in this workspace. A visible UI or schema alone does not count as a completed workflow.

## Feature Checklist

| Feature | Status | Evidence / notes |
|---|---|---|
| Flutter app bootstrap and theme | COMPLETED | `lib/main.dart`, `lib/core/theme/app_theme.dart` |
| Firebase initialization for Android/web | COMPLETED | `lib/core/firebase/firebase_options.dart`; other targets throw unsupported errors |
| Supabase Flutter initialization | COMPLETED | `lib/main.dart`, `lib/core/supabase/supabase_config.dart`; deployed policies unverified |
| Firebase email/password signup/login/logout/reset | COMPLETED | `lib/core/services/auth_service.dart`, `lib/features/auth/screens/` |
| Firestore user profile creation | COMPLETED | `AuthService.signup`, `lib/features/auth/services/user_service.dart` |
| Admin account provisioning | NOT IMPLEMENTED | No in-app role-management flow; manual provisioning details need verification |
| Client role-based dashboard routing | PARTIALLY IMPLEMENTED | `lib/core/routing/auth_wrapper.dart`; no checked-in security rules/backend role enforcement |
| Candidate dashboard and live job listing | COMPLETED | `lib/features/user/screens/user_dashboard.dart`, `lib/features/user/services/user_job_service.dart` |
| Resume upload/replacement and metadata | PARTIALLY IMPLEMENTED | `UserJobService.uploadOrReplaceResume`; Supabase bucket/policy configuration needs verification |
| Resume text chunking and embedding after upload | PARTIALLY IMPLEMENTED | `lib/features/user/services/resume_processing_service.dart`, `backend/app/main.py`, `backend/app/services/resume_embedding_service.py`, `backend/app/services/gemini_service.py`; requires reachable API, Gemini config, and applied pgvector migration |
| Supabase pgvector storage schema | PARTIALLY IMPLEMENTED | `supabase/migrations/20261105000000_resume_embeddings.sql`; migration application/deployed permissions need verification |
| Candidate job application creation | COMPLETED | `UserJobService.applyForJob`; deterministic ID and duplicate transaction check |
| Candidate application status view | PARTIALLY IMPLEMENTED | Candidate sees count/applied state; no full status workflow |
| Admin dashboard live job count/recent jobs | PARTIALLY IMPLEMENTED | `lib/features/admin/screens/overview_screen.dart`; other counts are fixed zero |
| Admin create/edit/close/delete jobs | COMPLETED | `lib/features/admin/services/admin_service.dart`, admin job screens |
| Admin real candidate list and review | NOT IMPLEMENTED | `lib/features/admin/screens/candidates_screen.dart` uses local sample data |
| Admin analytics from real data | NOT IMPLEMENTED | `lib/features/admin/screens/analytics_screen.dart` uses static values |
| Admin account display-name update | COMPLETED | `lib/features/admin/screens/settings_screen.dart` uses Firebase Auth |
| Company settings persistence | NOT IMPLEMENTED | Settings screen explicitly says it is local-only |
| Notification preference persistence/dispatch | NOT IMPLEMENTED | Switch values are local state; no notification integration |
| Backend Firebase ID-token verification | COMPLETED | `get_current_user` in `backend/app/main.py` |
| Resume embedding API trigger after upload | PARTIALLY IMPLEMENTED | `lib/features/user/services/resume_processing_service.dart`, `lib/core/network/api_config.dart`; `API_BASE_URL` must be set and reachable |
| Backend health endpoints | COMPLETED | `/`, `/health`, `/health/connections`; connection check is unauthenticated |
| PDF extraction with pdfplumber | PARTIALLY IMPLEMENTED | `backend/app/main.py`; text PDFs only, no OCR; embedding endpoint is called after upload, profile endpoint is not |
| Gemini candidate-profile extraction | PARTIALLY IMPLEMENTED | `backend/app/services/gemini_service.py`; endpoint exists but is not connected to Flutter |
| Candidate profile persistence | PARTIALLY IMPLEMENTED | Backend writes `candidate_profiles/{uid}`; no frontend consumer |
| Candidate/job matching algorithm | NOT IMPLEMENTED | `backend/app/schemas/job_matching_schema.py` contracts plus fully commented-out prototypes in `backend/app/routers/matching.py` and `backend/app/services/embedding_service.py`; nothing is registered or executable |
| Candidate ranking | NOT IMPLEMENTED | No ranking method or integrated screen |
| AI-personalized job offer | NOT IMPLEMENTED | No schema, service, prompt, endpoint, or UI |
| Admin offer review and approval | NOT IMPLEMENTED | No offer workflow |
| Offer delivery to candidate | NOT IMPLEMENTED | No email/notification/delivery integration |
| Firestore access rules in repository | NEEDS VERIFICATION | No `firestore.rules` file found; deployed rules are unknown |
| Supabase bucket privacy/policies | NEEDS VERIFICATION | Code references bucket `resumes`; console configuration not included |
| Non-Android/web Firebase targets | NEEDS VERIFICATION | Options explicitly unsupported in source; support is not configured |
| Automated application tests | PARTIALLY IMPLEMENTED | Python chunking unit tests exist; starter Flutter counter test does not match the current UI; API integrations are untested |

## Existing Issues and Incomplete Integrations

- **Test mismatch:** `test/widget_test.dart` expects a counter screen that is not present and pumps the app without the bootstrap in `main()`. The test should be run and replaced with relevant initialization/auth tests; its current passing status is not established.
- **ID token is printed:** `login_screen.dart` logs the Firebase ID token.
- **Embedding deployment required:** Upload invokes the API, but the Supabase migration must be applied and `API_BASE_URL`/Gemini configuration must be available.
- **Profile extraction remains separate:** The upload flow creates embeddings; it does not invoke `/api/resumes/screen`.
- **Candidate list is demo-only:** `CandidatesScreen` data/status/score changes are hard-coded/in-memory.
- **Analytics is demo-only:** `AnalyticsScreen` charts and metrics are fixed local lists.
- **Dashboard metrics incomplete:** Overview shows live job count, but candidate/review/shortlist metrics are fixed zeros.
- **Admin mobile navigation:** `AdminDashboard` hides the sidebar below 850 px and provides no alternate page navigation, leaving the other admin sections inaccessible at narrow widths.
- **Applicant-count mismatch:** Overview reads `job['applicants']`, but job creation does not write that field; absent data displays as zero.
- **Settings persistence incomplete:** Company and notification controls are not persisted; email is read-only.
- **Security configuration absent from repo:** No Firestore rules or Supabase Storage policies; actual deployed settings need verification.
- **Secret hygiene:** `backend/.env` exists and is ignored by `backend/.gitignore`. Confirm it is not tracked and protect other environment/service-account files. `set_supabase_claims.py` contains a local absolute service-account path.
- **Unpinned Python dependencies:** `backend/requirements.txt` lists dependencies without versions; `openai` is declared but not used by current backend source.
- **Test coverage gap:** The Python suite only covers chunking; no matching, API, auth, or data-service integration tests exist. The starter Flutter counter test is still unrelated to the app.

## Technical Debt

- Client code directly accesses Firestore; access control is not documented/configured in repository.
- Data types are mostly dynamic maps in feature services/screens.
- Backend mixes initialization, routes, storage, and persistence in one `main.py`.
- Embedding is synchronous within a request; there is no queue or automatic retry.
- Errors are surfaced to clients inconsistently; backend validation statuses are preserved for the current routes.
- Resume/application data is duplicated by value; no cleanup cascade is implemented when jobs/resumes/users are removed.
- Python requirements have no version constraints or lock file in the workspace.

## Recommended Development Steps

1. **Immediate, exact next task:** Apply `supabase/migrations/20261105000000_resume_embeddings.sql`, configure `API_BASE_URL` and Gemini embedding access, then smoke-test upload-to-`resume_embeddings` end to end. Confirm a replacement removes prior vectors and a failed embedding leaves a visible failed status.
2. Verify least-privilege Firestore rules and Supabase Storage policies for UID-scoped objects; confirm admin-only job writes and candidate-owned resume/application access.
3. Remove Firebase ID-token debug logging and ensure `.env` and service-account files remain excluded from source control.
4. Add backend integration tests for auth failure, missing resume, owner mismatch, invalid/unreadable PDF, Gemini failure, Supabase RPC failure, and success.
5. Add a vector similarity search path and job description embeddings before describing candidate-job matching as implemented.
6. Replace demo candidate and analytics data with Firestore-backed queries and persisted review state.
7. Implement and evaluate matching/ranking only after defining a transparent score formula and data contract.
8. Add offer generation, review/approval, delivery, and candidate visibility as separate, tested workflows.
9. Replace the starter widget test and add real Flutter/backend coverage.

## Verification Caveats

No deployed project console, service-account file, or `.env` content was inspected. Actual data, rules, Supabase bucket privacy, Gemini model availability, and production runtime behavior are **Needs verification**.
