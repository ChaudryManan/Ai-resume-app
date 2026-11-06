# Copilot Instructions

- Understand the project architecture and read the relevant `docs/` pages before coding.
- Inspect actual source files and verify whether a feature is implemented before extending it.
- Follow existing patterns and naming conventions; keep Flutter presentation/data access separate from FastAPI processing.
- Maintain the Flutter and FastAPI separation. The Flutter app currently has no API client integration; do not assume one exists.
- Respect Firebase Authentication and Firestore role-based routing, but do not treat client-side routing as authorization. Preserve or strengthen server-side and database access controls.
- Use Supabase Storage for resume file storage as currently implemented. Do not move resume files to Firebase Storage unless the architecture is explicitly changed.
- Store resume vectors in Supabase PostgreSQL with pgvector through the backend-only RPC and migration; keep vector data and resume chunks out of Firestore documents.
- Follow the existing backend AI service architecture (`backend/app/services/gemini_service.py`) and Pydantic schemas. Do not invent AI behavior, prompts, matching formulas, or offer workflows.
- Avoid hardcoded credentials, tokens, and secret values. Never log Firebase ID tokens or commit local `.env`/service-account files.
- Avoid unnecessary dependencies and duplicate services, models, and endpoints.
- Never generate fake data unless explicitly requested. Existing candidate/analytics screens contain demo data; do not present it as live data.
- Provide complete, integrated implementations with exact file paths and explain required configuration, permissions, and dependencies.
- Make changes incrementally, preserve working behavior, and test existing functionality after modifications.
- Update related documentation whenever implementation or behavior changes.
- Treat missing Firestore rules, Supabase Storage policies, and deployed configuration as unverified until inspected.
