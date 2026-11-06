# Setup Guide

This guide is based on the checked-in source. Console-side Firebase/Supabase configuration is not included and must be supplied by the project owner. Never commit credentials or paste them into source control.

## Prerequisites

- Git.
- Flutter SDK with Dart satisfying the `^3.11.0` constraint in `pubspec.yaml`.
- Android Studio/Android SDK for Android builds, or a supported configured web target.
- Python installation compatible with current FastAPI, Firebase Admin, Supabase, and Google Gen AI dependencies. The project does not pin a Python version; **Needs verification** for deployment target.
- A Firebase project configured for Email/Password Auth and Cloud Firestore.
- A Supabase project and a Storage bucket named `resumes`.
- Access to the Supabase SQL Editor to apply the pgvector schema migration.
- A Gemini API key and a model available to that API.

The checked-in Dart Firebase options support Android and web. iOS/macOS/Windows/Linux Firebase configurations need to be generated/verified before running on those targets.

## Flutter Setup

From the project root in PowerShell:

```powershell
flutter --version
flutter pub get
```

Configure Firebase for the intended platforms using the FlutterFire CLI and the project's Firebase project. Keep the generated config private to the repository's normal handling; do not paste API keys into these docs. Android also uses `android/app/google-services.json` with the Google Services Gradle plugin. If regenerating platform config, review the result rather than copying values into unrelated files.

Supabase Flutter settings are read by `lib/core/supabase/supabase_config.dart`; the app expects a Supabase project URL and publishable key there. The code passes the current Firebase ID token through the Supabase client's access-token callback. Do not put a Supabase server secret in the Flutter app.

## Backend Setup

Create and activate a virtual environment from PowerShell:

```powershell
Set-Location .\backend
py -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install --upgrade pip
pip install -r requirements.txt
```

`backend/.env` is read by `python-dotenv` when launching with the backend directory as the working directory. Supply these variable names locally (placeholder values only):

```dotenv
SUPABASE_URL=<your Supabase project URL>
SUPABASE_SECRET_KEY=<server-side Supabase secret>
FIREBASE_SERVICE_ACCOUNT_PATH=<absolute path to protected Firebase Admin service-account JSON>
GEMINI_API_KEY=<your Gemini API key>
GEMINI_MODEL=<optional Gemini model override>
GEMINI_EMBEDDING_MODEL=<optional embedding model override; keep 768 dimensions>
FRONTEND_ORIGINS=<comma-separated browser origins for Flutter Web>
```

The key names above match the code. Do not commit the file or service-account JSON. At the time of this documentation, `backend/.env` exists locally; its contents were not inspected. `backend/.gitignore` contains an `.env` rule and Git reports this file as ignored. Verify it is not tracked and protect any other environment files with appropriate ignore rules before committing.

The backend validates Supabase URL/secret and Firebase service-account path/file during import. The Gemini service also raises if `GEMINI_API_KEY` is absent. `GEMINI_MODEL` is optional and has a source default.

### Apply the vector database migration

Before using resume upload processing, apply `supabase/migrations/20261105000000_resume_embeddings.sql` to the same Supabase project as the `resumes` Storage bucket. It creates the `resume_embeddings` table, pgvector index, RLS policy boundary, and backend RPC. Use the Supabase SQL Editor or your reviewed migration workflow. Do not call the embedding endpoint until migration succeeds.

The configured embedding model must return 768 dimensions to match the table. The code defaults to `gemini-embedding-001` and 768 dimensions.

Run the API from `backend`:

```powershell
Set-Location .\backend
.\.venv\Scripts\Activate.ps1
uvicorn app.main:app --reload --host 0.0.0.0
```

The API listens on port 8000. Interactive docs are normally at `http://127.0.0.1:8000/docs`. No production server/deployment configuration is included. For Flutter Web, set `FRONTEND_ORIGINS` in the backend environment to the exact browser origin(s); CORS is disabled unless this is configured.

## Start the Flutter App

In another PowerShell terminal from the project root:

```powershell
flutter devices
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
```

That example is for an Android emulator reaching a host-machine backend. For Flutter Web use `http://127.0.0.1:8000`; for a physical device or production build, use a backend URL reachable from that device, preferably HTTPS. Set `API_BASE_URL` at build/run time; it is a URL, not a secret. Do not assume every Flutter platform is usable: Firebase options currently support Android/web only.

## Functional Setup Checklist

1. Enable Firebase Email/Password sign-in.
2. Create/configure Firestore and verify least-privilege rules; no rules file is included.
3. Create the Supabase `resumes` bucket and verify private access and UID-scoped policies; bucket privacy cannot be inferred from the client code.
4. Verify Supabase accepts the Firebase JWT flow expected by `supabase_flutter`; the helper script that sets claims is privileged and should not be run without review.
5. Provision an admin account by a secure process that sets the Firestore user role. No admin provisioning UI exists.
6. Configure backend environment variables and confirm Firebase Admin can access Firestore.
7. Apply the Supabase pgvector migration and confirm the backend service role can execute its replacement RPC.
8. Configure `GEMINI_API_KEY`, optional `GEMINI_EMBEDDING_MODEL`, `API_BASE_URL`, and `FRONTEND_ORIGINS` for the chosen platform.
9. Upload a text-based PDF through Flutter and confirm `resumes/{uid}.embeddingStatus` becomes `completed` and a matching number of rows appears in `resume_embeddings`. OCR is not implemented.
10. `/api/resumes/screen` remains a separate profile extraction route; Flutter does not call it.

## Tests and Checks

From project root:

```powershell
flutter analyze
flutter test
```

The only checked-in Flutter test is a starter counter test that does not match the current app and may also require Firebase initialization. Update/replace it before relying on its result.

From `backend` with the virtual environment active:

```powershell
python -m compileall app
python -m unittest discover -s tests -v
```

Focused chunking tests are in `backend/tests`. Integration tests against Firebase, Gemini, and Supabase still need to be added. `GET /health` reports initialization, while `GET /health/connections` attempts actual Firestore/Supabase calls.

## Not Included / Needs Verification

- Firebase project-specific rules, indexes, and role provisioning.
- Supabase bucket policy/privacy and any external JWT integration settings.
- Production hosting, HTTPS, CORS, domains, secrets management, and monitoring.
- iOS/macOS/Windows/Linux Firebase setup.
- Gemini model access/availability and quotas.
- Deployed credentials and current live data.
