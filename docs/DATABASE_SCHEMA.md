# Database and Storage Schema

## Scope and Confidence

The fields below are derived from Firestore SDK writes/reads in the repository. Firestore is schemaless: fields may vary in production or be written by code outside this workspace. No Firestore rules file was found. The actual deployed rules, indexes, existing data, and Supabase policies are **Needs verification**.

Firestore server timestamps are represented as Firestore `Timestamp` values when resolved. Document IDs are described separately from document fields.

## Firestore Collections

### `users/{uid}`

Written during registration by `AuthService.signup`; read by `UserService`.

| Field | Type | Source / meaning |
|---|---|---|
| `uid` | string | Firebase Auth UID |
| `name` | string | Trimmed signup name |
| `email` | string | Trimmed signup email |
| `role` | string | Registration writes `"user"`; `AuthWrapper` recognizes `"user"` and `"admin"` |
| `createdAt` | Firestore server timestamp | Registration time |

**Document ID:** Firebase Auth UID. No app UI for creating/administering admins was found.

### `jobs/{jobId}`

Created using Firestore `add()` by `AdminService.createJob`; queried in admin and candidate screens.

| Field | Type | Source / meaning |
|---|---|---|
| `title` | string | Trimmed title |
| `department` | string | Trimmed department |
| `location` | string | Trimmed location |
| `jobType` | string | Selected job type |
| `salary` | string | Trimmed salary |
| `description` | string | Trimmed description |
| `responsibilities` | string | Trimmed responsibilities |
| `education` | string | Education selection |
| `experience` | string | Experience selection |
| `skills` | list of strings | Comma-separated UI input trimmed and split |
| `status` | string | Initially `"Active"`; management UI switches `"Active"`/`"Closed"` |
| `createdBy` | string | Creating Firebase UID |
| `createdAt` | Firestore server timestamp | Creation time |
| `updatedAt` | Firestore server timestamp | Creation/update time |

**Document ID:** Firestore-generated ID. `AdminService.updateJob` accepts a generic map and updates `updatedAt`; the edit UI changes title, department, and location, while status actions change `status`. Deletion removes the job document only.

The candidate client reads `jobs` ordered by `createdAt` descending and filters status `"Active"` in memory. Admin also reads the ordered stream. Firestore indexes required by the deployed queries need verification.

### `resumes/{uid}`

Written by `UserJobService.uploadOrReplaceResume`; read by the candidate screen and backend.

| Field | Type | Source / meaning |
|---|---|---|
| `uid` | string | Firebase Auth UID |
| `fileName` | string | Original selected filename |
| `storagePath` | string | UID-prefixed path in Supabase `resumes` bucket |
| `bucket` | string | `"resumes"` |
| `uploadedAt` | Firestore server timestamp | Set on upload/replacement |
| `updatedAt` | Firestore server timestamp | Set on upload/replacement |
| `embeddingStatus` | string | `"pending"`, `"processing"`, `"completed"`, or `"failed"` as upload/backend processing progresses |
| `embeddingModel` | string | Gemini embedding model used on successful processing |
| `embeddingDimensions` | integer | Vector size; currently 768 |
| `embeddingChunkCount` | integer | Number of chunks stored for the current resume |
| `embeddedAt` | Firestore server timestamp | Successful embedding time |

**Document ID:** Firebase UID; this is one current-resume metadata document per account. The file itself is not stored in Firestore.

### `applications/{uid}_{jobId}`

Created by `UserJobService.applyForJob` in a Firestore transaction after checking that the current user's resume exists.

| Field | Type | Source / meaning |
|---|---|---|
| `uid` | string | Applying Firebase UID |
| `userName` | string | Firebase Auth display name or empty string |
| `email` | string | Firebase Auth email or empty string |
| `jobId` | string | Firestore job document ID |
| `jobTitle` | string | Title passed from the candidate UI |
| `status` | string | Initially `"Pending"` |
| `resumeFileName` | string | Name copied from resume metadata |
| `resumePath` | string | Supabase storage path copied from metadata |
| `resumeBucket` | string | `"resumes"` |
| `appliedAt` | Firestore server timestamp | Submission time |

**Document ID:** Deterministic string `${uid}_${jobId}`; the transaction refuses to create it if already present. There is no admin application query/status update implementation in the reviewed code.

### `candidate_profiles/{uid}`

Written by `POST /api/resumes/screen` with `merge=True`. No Flutter reader was found.

| Field | Type | Source / meaning |
|---|---|---|
| `uid` | string | Firebase UID from verified ID token |
| `resumeFileName` | string or null | Copied from resume metadata |
| `resumeStoragePath` | string | Storage path from resume metadata |
| `screening_status` | string | Set to `"completed"` after successful extraction |
| `profile` | map | `CandidateProfile.model_dump()` |
| `screenedAt` | Firestore server timestamp | Successful screening time |

`profile` fields from `backend/app/schemas/resume_schema.py`:

| Field | Type |
|---|---|
| `full_name` | string or null |
| `professional_title` | string or null |
| `email` | string or null |
| `phone` | string or null |
| `location` | string or null |
| `professional_summary` | string or null |
| `education` | list of maps: `degree`, `institution`, `graduation_year` (each string or null) |
| `total_experience` | string or null |
| `work_experience` | list of maps: `company`, `job_title`, `duration` (each string or null), `responsibilities` (list of strings) |
| `technical_skills` | list of strings |
| `certifications` | list of strings |
| `projects` | list of strings |
| `languages` | list of strings |

**Document ID:** Firebase UID. Pydantic schema fields are snake_case; Firestore envelope fields use the spellings shown above.

## Schema-Only Matching Contracts

`backend/app/schemas/job_matching_schema.py` declares fields but no writes or operational matching path:

- `JobRequirements`: `job_id`, `title`, `required_skills`, `minimum_experience_months`, `education_requirements`, `other_requirements`.
- `MatchScores`: `skill_score`, `experience_score`, `education_score`, `other_requirements_score`, `overall_score`.
- `CandidateMatchResult`: `candidate_uid`, optional `candidate_name`, `job_id`, nested `scores`, `matched_skills`, `missing_skills`, optional `explanation`, and `matching_status`.

These are not confirmed Firestore fields or persisted records. No score weights or calculation formula exists in code.

## Relationships

- Firebase Auth UID → `users/{uid}`, `resumes/{uid}`, `candidate_profiles/{uid}`.
- `resume_embeddings.user_id` associates vector chunks with the Firebase UID; `resume_path` scopes them to the uploaded resume object.
- `applications/{uid}_{jobId}` refers to the same user through `uid`, and to `jobs/{jobId}` through `jobId`.
- Application records copy job title and resume file metadata/path at application time; these can diverge from later edits/replacements.
- `jobs.createdBy` stores a UID but no query or join is implemented from it in the reviewed app.

## Security Rules

- No `firestore.rules` or `storage.rules` file is present in the workspace.
- `firebase.json` includes FlutterFire platform configuration only; it does not configure Firestore rules or indexes.
- Deployed Firestore rules and Firebase Storage rules are **Needs verification**.
- The Admin SDK in FastAPI bypasses Firestore client security rules, so backend authorization and service-account access must be reviewed independently.

Do not treat client-side role routing as database access control.

## Supabase Storage

| Bucket | Object path | Data |
|---|---|---|
| `resumes` | `{uid}/{millisecondsSinceEpoch}_{sanitizedFilename}` | PDF bytes; Flutter sets `contentType: application/pdf` and `upsert: false` |

The Flutter upload limits input to 5 MiB and sanitizes path characters. Backend checks that the metadata bucket is `"resumes"`, the path starts with the authenticated UID plus `/`, the downloaded bytes begin with `%PDF-`, and extracted text is not empty.

## Supabase PostgreSQL Vector Table

The migration `supabase/migrations/20261105000000_resume_embeddings.sql` defines:

### `public.resume_embeddings`

| Column | Type | Meaning |
|---|---|---|
| `id` | generated bigint primary key | Row identifier |
| `user_id` | text | Firebase UID from the verified backend token |
| `resume_path` | text | UID-prefixed current object path in Supabase Storage |
| `chunk_index` | integer | Zero-based order of the resume chunk |
| `content` | text | Normalized resume text for this chunk; sensitive personal data |
| `embedding` | `extensions.vector(768)` | Gemini `gemini-embedding-001` retrieval-document vector |
| `created_at` | timestamptz | Row creation time |

Unique key: `(user_id, resume_path, chunk_index)`. An HNSW index uses cosine distance. Row-level security is enabled, direct access is revoked from `anon` and `authenticated`, and the backend-only `replace_resume_embeddings` RPC is executable by `service_role`. The RPC validates the UID-prefixed path and atomically replaces all existing vector rows for that user.

The Flutter app does not directly read or write this table. Keep the Supabase secret on the backend only. A matching/search RPC or endpoint is **not implemented** yet. Apply the migration before calling the embedding API.

Bucket privacy, policies, object retention, encryption settings, and max-size restrictions configured in Supabase are **Needs verification**. The project does not define Supabase policies in source.
