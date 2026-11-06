# Development Decisions

This record separates decisions confirmed by source from recommendations. It does not assume that a technology choice is complete or production-ready merely because a dependency is present.

## Confirmed by the Repository

| Area | Confirmed implementation |
|---|---|
| Client | Flutter/Dart, Material UI, feature folders under `lib/features/` |
| Client state | Local widget state and Firebase `StreamBuilder`; no declared app state-management package |
| Authentication | Firebase email/password Auth |
| Role routing | `users/{uid}.role` determines client dashboard |
| Main database | Cloud Firestore accessed directly by Flutter and via Firebase Admin in backend |
| File storage | Supabase Storage bucket named `resumes`; Firestore stores resume metadata |
| Resume vectors | Supabase PostgreSQL with pgvector; PDF objects remain in Storage, while Firestore tracks embedding status/model/count |
| Backend | FastAPI app in `backend/app/main.py` |
| Backend authentication | Firebase Admin verifies Firebase ID bearer token |
| PDF processing | `pdfplumber` text extraction |
| AI extraction | Google Gen AI SDK requests JSON using Pydantic `CandidateProfile` response schema |
| Resume embeddings | Gemini `gemini-embedding-001`, `RETRIEVAL_DOCUMENT`, 768 dimensions; 1,800-character chunks with 200-character overlap |
| Matching | Pydantic schema contracts exist; computation does not |
| Platform configuration | FlutterFire configuration is present for Android and web; other targets throw unsupported errors |
| Local environment | Backend uses `python-dotenv`; `backend/.env` exists locally but its values were not inspected |

## Not Confirmed

- Why Firebase, Firestore, Supabase, FastAPI, or Gemini were chosen over alternatives.
- Whether Supabase Storage is configured as private or uses policies compatible with Firebase JWTs.
- Whether the pgvector migration has been applied to the configured Supabase project.
- Whether the configured `API_BASE_URL` is reachable from each target platform.
- Whether deployed Firestore rules restrict direct client writes and admin functions.
- Whether the configured Gemini model is enabled for the deployment.
- Whether any cloud hosting, CI/CD, backup, monitoring, retention, or privacy process exists.
- Whether local demo candidate/analytics values are intended as placeholders or product acceptance data.

## Recommendations (Not Existing Decisions)

1. Keep the Flutter presentation layer, Firestore/storage operations, and FastAPI AI work separated; do not duplicate service implementations.
2. Establish enforceable security policies before implementing more client-side admin features.
3. Use server-side authorization for privileged operations and least-privilege Firebase/Supabase credentials.
4. Define versioned request/response contracts between Flutter and FastAPI before adding API calls.
5. Define matching score formula, evidence, data shape, and human-review rules before implementing ranking.
6. Store offer lifecycle as explicit server-backed state only after defining approval and delivery requirements.
7. Pin and periodically review Python dependencies; remove unused dependencies such as `openai` if confirmed unnecessary.
8. Add automated tests around service logic and integration boundaries.
9. Keep secrets in ignored local files or a deployment secret manager; never embed server-side secrets in Flutter.
