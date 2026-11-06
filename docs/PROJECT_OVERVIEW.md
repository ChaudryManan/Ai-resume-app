# Project Overview

## Introduction

The **AI-Powered Resume Screener and Recruitment Management System** (the Flutter UI uses the names *HireFlow* and *Resume Screener*) is a Flutter application with Firebase-backed accounts, job postings, applications, and resume metadata. Resume files are uploaded to Supabase Storage. A separate FastAPI backend can extract text from a candidate's PDF and request structured profile extraction from Gemini.

The source code verifies those building blocks, but not every capability in the product description is connected end to end. In particular, the Flutter client does not call the screening endpoint, and matching, candidate ranking, and job-offer generation are not implemented.

## Problem Statement

Recruiting teams need a place to publish openings and collect candidate applications, while candidates need to manage a resume and apply. The project is intended to reduce manual resume-review effort through AI-assisted extraction. The currently implemented application covers account entry, job management, resume upload, and application submission; AI matching and recruitment decision workflows remain incomplete.

## Objectives

- Provide email/password registration and login using Firebase Authentication.
- Route signed-in accounts to candidate or administrator UI according to a Firestore role field.
- Let admins create and manage job postings in Cloud Firestore.
- Let candidates upload a PDF resume to Supabase Storage and submit an application to a job.
- Provide a protected backend operation that extracts profile fields from resume PDF text using Gemini.
- Establish clear next steps for securely connecting and completing the screening workflow.

## Target Users

- **Candidates/users:** Register, manage one resume, browse active jobs, and apply.
- **Administrators/recruiters:** Create, edit, close, and delete jobs; view the current admin dashboard.

The current candidate-review screen contains local demo records rather than Firestore-backed candidates. Do not treat those records or scores as real recruitment data.

## Main Features and Actual Status

| Capability | Current implementation |
|---|---|
| Email/password sign-up and login | Implemented with Firebase Authentication |
| Role-based dashboard routing | Implemented in the client using `users/{uid}.role`; this is not server-side authorization |
| Job creation and management | Implemented against Firestore |
| Candidate resume upload/replacement | Implemented against Supabase Storage with Firestore metadata |
| Applying for a job | Implemented against Firestore, with a deterministic application document ID |
| Resume vector embedding on upload | Implemented in code using Gemini embeddings and Supabase pgvector; requires applying the SQL migration and configuring the backend URL |
| PDF text extraction and Gemini profile extraction | Backend implementation exists; no Flutter call to it was found |
| Candidate list and selection controls | UI is a local, hard-coded demo; changes are not persisted |
| Recruitment analytics | Static sample values; not backed by application data |
| Candidate/job matching and ranking | Not implemented; only Pydantic schema classes exist |
| Personalized job offer generation and delivery | Not implemented |

See [IMPLEMENTATION_STATUS.md](./IMPLEMENTATION_STATUS.md) for a feature-by-feature assessment.

## Technologies Verified in Source

- **Frontend:** Flutter and Dart (`pubspec.yaml` requires Dart `^3.11.0`).
- **Authentication and database:** Firebase Authentication, Cloud Firestore, and Firebase Admin SDK on the backend.
- **File storage:** Supabase Storage (`resumes` bucket name in code).
- **Backend:** Python, FastAPI, Uvicorn, Pydantic, `pdfplumber`, and `python-dotenv`.
- **AI:** Google Gen AI Python SDK, configured to use a Gemini model.
- **Other declared dependencies:** Flutter `file_picker`, `supabase_flutter`, Firebase Flutter packages; Python `openai` appears in requirements but is not imported by the application source.

Firebase configuration is present for Android and web in the FlutterFire configuration. iOS, macOS, Windows, and Linux Firebase options throw `UnsupportedError` in the checked-in Dart options file.

## System Capabilities

1. Authenticate accounts and store user profile/role data in Firestore.
2. Provide an admin UI for CRUD operations on Firestore job postings.
3. Provide a candidate UI to list active openings, search by title/department/location, upload or replace one PDF resume, and apply once per job.
4. Save resume metadata in Firestore and binary data in Supabase Storage.
5. Allow an authenticated Firebase user to invoke the backend resume-screening endpoint directly, if supplied with a Firebase ID token and a configured backend.
6. Extract resume text from text-readable PDFs, call Gemini for a Pydantic-constrained profile, and save that result in Firestore.

The resume-embedding path is wired into the Flutter upload flow. Actual operation still requires deploying the SQL migration and supplying a reachable API base URL.
