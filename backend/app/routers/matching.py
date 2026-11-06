# import logging

# from fastapi import APIRouter, Depends, HTTPException, Query
# from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
# from firebase_admin import auth, firestore

# from app.services import embedding_service as emb
# from app.services.matching_service import score_candidate

# logger = logging.getLogger("hireflow.matching")

# router = APIRouter(tags=["matching"])
# bearer = HTTPBearer()

# # Final score = SEMANTIC_WEIGHT * semantic (vectors) + rest * structured (skills/exp/edu)
# SEMANTIC_WEIGHT = 0.70


# def get_user(credentials: HTTPAuthorizationCredentials = Depends(bearer)):
#     try:
#         return auth.verify_id_token(credentials.credentials)
#     except Exception:
#         raise HTTPException(status_code=401, detail="Invalid or expired Firebase token.")


# def require_admin(decoded: dict = Depends(get_user)):
#     snap = firestore.client().collection("users").document(decoded["uid"]).get()
#     role = (snap.to_dict() or {}).get("role") if snap.exists else None
#     if role != "admin":
#         raise HTTPException(status_code=403, detail="Admin access required.")
#     return decoded


# @router.post("/api/resumes/embed")
# def embed_my_resume(user: dict = Depends(get_user)):
#     """Create/refresh the vector for the caller's analyzed resume."""
#     uid = user["uid"]
#     db = firestore.client()

#     snap = db.collection("candidate_profiles").document(uid).get()
#     profile = (snap.to_dict() or {}).get("profile") if snap.exists else None
#     if not profile:
#         raise HTTPException(
#             status_code=404,
#             detail="No analyzed resume found. Screen the resume first.",
#         )

#     try:
#         vectors = emb.get_or_create_candidate_vectors(db, {uid: profile})
#     except Exception as error:
#         logger.error("Embedding failed uid=%s: %s: %s", uid, type(error).__name__, error)
#         raise HTTPException(status_code=502, detail="The AI embedding service failed.")

#     if uid not in vectors:
#         raise HTTPException(status_code=422, detail="Resume has no content to embed.")
#     return {"status": "success", "dimensions": len(vectors[uid])}


# @router.post("/api/jobs/{job_id}/match")
# def match_job(
#     job_id: str,
#     top_n: int = Query(20, ge=1, le=100),
#     admin: dict = Depends(require_admin),
# ):
#     db = firestore.client()

#     job_snap = db.collection("jobs").document(job_id).get()
#     if not job_snap.exists:
#         raise HTTPException(status_code=404, detail="Job not found.")
#     job = job_snap.to_dict() or {}

#     try:
#         profiles: dict[str, dict] = {}
#         file_names: dict[str, str | None] = {}
#         for doc in db.collection("candidate_profiles").stream():
#             data = doc.to_dict() or {}
#             if data.get("profile"):
#                 profiles[doc.id] = data["profile"]
#                 file_names[doc.id] = data.get("resumeFileName")

#         try:
#             job_vec = emb.get_or_create_job_vector(db, job_id, job)
#             cand_vecs = emb.get_or_create_candidate_vectors(db, profiles)
#         except Exception as error:
#             logger.error(
#                 "Embedding failed job=%s: %s: %s", job_id, type(error).__name__, error
#             )
#             raise HTTPException(
#                 status_code=502, detail="The AI embedding service failed."
#             )

#         results = []
#         for uid, profile in profiles.items():
#             structured = score_candidate(job, profile)

#             vec = cand_vecs.get(uid)
#             sim = emb.cosine(job_vec, vec) if vec else None
#             semantic = emb.similarity_to_score(sim) if sim is not None else 0.0

#             final = (
#                 SEMANTIC_WEIGHT * semantic
#                 + (1 - SEMANTIC_WEIGHT) * structured["overall_score"]
#             )
#             results.append(
#                 {
#                     **structured,
#                     "overall_score": round(final, 1),
#                     "structured_score": structured["overall_score"],
#                     "semantic_score": semantic,
#                     "semantic_similarity": round(sim, 4) if sim is not None else None,
#                     "candidate_uid": uid,
#                     "candidate_name": profile.get("full_name"),
#                     "resume_file_name": file_names.get(uid),
#                 }
#             )

#         results.sort(key=lambda r: r["overall_score"], reverse=True)
#         for rank, result in enumerate(results, start=1):
#             result["rank"] = rank

#         unscreened = sum(
#             1
#             for doc in db.collection("users").stream()
#             if (doc.to_dict() or {}).get("role") == "user" and doc.id not in profiles
#         )

#         top = results[:top_n]

#         db.collection("job_matches").document(job_id).set(
#             {
#                 "jobId": job_id,
#                 "jobTitle": job.get("title"),
#                 "matchedBy": admin["uid"],
#                 "matchedAt": firestore.SERVER_TIMESTAMP,
#                 "semanticWeight": SEMANTIC_WEIGHT,
#                 "totalScreened": len(results),
#                 "candidatesWithoutProfile": unscreened,
#                 "results": top,
#             }
#         )

#         return {
#             "status": "success",
#             "job_id": job_id,
#             "job_title": job.get("title"),
#             "total_screened": len(results),
#             "candidates_without_profile": unscreened,
#             "results": top,
#         }

#     except HTTPException:
#         raise
#     except Exception as error:
#         logger.error("Matching failed job=%s: %s: %s", job_id, type(error).__name__, error)
#         raise HTTPException(status_code=500, detail="Matching failed.")