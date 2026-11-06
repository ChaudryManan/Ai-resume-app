# Authentication and Security

## Firebase Authentication

- The Flutter app uses Firebase email/password sign-up, sign-in, sign-out, auth-state changes, and password reset through `AuthService`.
- Signup creates a Firebase Auth user, updates `displayName`, then writes `users/{uid}` in Firestore.
- Login obtains the current Firebase ID token. **Current code prints this token via `debugPrint`; remove this logging before release and treat any exposed token as sensitive.**
- Firebase configuration files are present for Android and web. Do not copy their API key/config values into documentation or public examples.
- `DefaultFirebaseOptions` explicitly rejects iOS, macOS, Windows, and Linux until reconfigured.

## Roles and Authorization

- Signup always creates Firestore role `"user"`.
- `AuthWrapper` uses the Firestore `role` field for dashboard routing (`admin` or `user`).
- No in-app admin creation or role-management flow exists.
- This routing is a client-side UI decision, not a secure boundary. A user who can access Firestore must not be trusted to enforce admin privileges.
- The backend verifies Firebase ID tokens but does not check an admin role; screening is limited to the token UID's own resume path.
- No Firestore rules file was found. Deployed rules, IAM permissions, Firebase custom claims, and admin provisioning are **Needs verification**.

## Firestore and Supabase Storage

- Flutter accesses Firestore directly for `users`, `jobs`, `resumes`, and `applications`.
- Resume PDFs use Supabase Storage bucket `resumes`, with a UID-prefixed object path. The backend checks that prefix before download.
- Resume text chunks and embeddings are stored in Supabase PostgreSQL by the backend-only `replace_resume_embeddings` RPC. The migration enables RLS and revokes direct `anon`/`authenticated` table access; apply and verify it on the target project.
- Flutter passes a current Firebase ID token to the Supabase client's `accessToken` callback.
- `set_supabase_claims.py` sets custom claim `role=authenticated` on every Firebase user it pages through. It uses a machine-specific service-account file path and requires privileged Firebase access. Review the intended Supabase JWT integration and test claims before running it; it is not part of startup.
- Supabase bucket privacy and deployed Storage policies are not represented in the repository and need verification.
- Firebase Storage is a declared Flutter dependency but no use was found.

## Backend Environment and Secrets

Backend configuration names read by source:

| Variable | Purpose |
|---|---|
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_SECRET_KEY` | Server-side Supabase access |
| `FIREBASE_SERVICE_ACCOUNT_PATH` | Path to Firebase Admin service-account JSON |
| `GEMINI_API_KEY` | Gemini API authentication |
| `GEMINI_MODEL` | Optional model override; source provides a default |
| `GEMINI_EMBEDDING_MODEL` | Optional resume embedding model override; database is currently fixed at 768 dimensions |
| `FRONTEND_ORIGINS` | Optional comma-separated allowed browser origins for FastAPI CORS |

`backend/.env` exists in the workspace, but its contents were intentionally not read or copied into these docs. `backend/.gitignore` contains an `.env` rule and Git reports this specific file as ignored. The root `.gitignore` does not contain a general `.env` rule, so protect any other environment files and service-account JSON as well. Use a protected local environment file or secret manager, confirm no credentials are tracked, rotate any credential that has been exposed, and keep production values out of the Flutter client. The Flutter Supabase publishable key is configured in source; never place the server secret there.

## Observed Risks and Recommendations

1. **ID token debug logging:** `lib/features/auth/screens/login_screen.dart` prints the bearer token. Remove it; never log auth tokens.
2. **Missing checked-in rules:** No Firestore rules or Supabase Storage policy definitions are present. Verify deployed policies and add least-privilege rules before production.
3. **Client-side admin routing:** The role is read on the client and no Firestore rules are available to verify that admin writes are restricted. Enforce roles in rules and backend checks as appropriate.
4. **Broad backend exception handling:** `/api/resumes/screen` turns in-route HTTP errors into generic HTTP 500s and prints detailed exception information. Preserve safe error semantics and avoid leaking provider responses in logs.
5. **Unauthenticated connection diagnostics:** `/health/connections` reveals caught exception text in its 503 response. Review whether it should be public and sanitize errors.
6. **Environment-file exposure risk:** `backend/.env` exists and is ignored by `backend/.gitignore`; verify that the effective ignore policy remains in place and that no credentials are tracked elsewhere. Protect/rotate secrets if needed.
7. **Privileged helper script:** `set_supabase_claims.py` uses a fixed local credential path and modifies claims for all users it enumerates. Review scope and operational safeguards before execution.
8. **Resume data sensitivity:** Resumes and extracted profiles are personal data. Define retention, deletion, consent, access audit, and data-processing policies; none are established by the code inspected.
9. **Upload trust boundary:** The 5 MiB check is client-side. Enforce file size/content type and safe processing limits server-side as well.
10. **Embeddings are sensitive:** Stored chunk text and vectors may contain personal data. Keep table access backend-only, verify RLS/grants and retention, and avoid returning full chunk text to clients unnecessarily.
11. **AI safety:** The extraction prompt includes instructions to avoid unsupported claims and ignore embedded instructions, but extracted data still requires validation and human review. No fairness evaluation or decision-automation controls are implemented.

This document is a source review, not verification of deployed Firebase/Supabase console configuration or an exhaustive security assessment.
