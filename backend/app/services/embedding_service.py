# """Gemini embeddings for resumes and jobs, plus cosine similarity."""
# import hashlib
# import math
# import os
# from typing import Any

# from firebase_admin import firestore

# DIMS = 768
# BATCH_SIZE = 50
# MAX_CHARS = 8000

# # Raw cosine similarity of related texts clusters in a narrow band, so it is
# # stretched to 0-100. These bounds are a starting guess; tune them after you
# # see real numbers. Ranking order is not affected by them.
# SIM_FLOOR = 0.50
# SIM_CEIL = 0.85


# def embedding_model() -> str:
#     return os.getenv("GEMINI_EMBEDDING_MODEL", "gemini-embedding-001")


# # ---------- text building (no name/email/phone/location/salary) ----------

# def profile_to_text(profile: dict[str, Any]) -> str:
#     lines: list[str] = []
#     if profile.get("professional_title"):
#         lines.append(f"Title: {profile['professional_title']}")
#     if profile.get("professional_summary"):
#         lines.append(f"Summary: {profile['professional_summary']}")
#     if profile.get("total_experience"):
#         lines.append(f"Total experience: {profile['total_experience']}")
#     if profile.get("technical_skills"):
#         lines.append("Skills: " + ", ".join(profile["technical_skills"]))
#     for job in profile.get("work_experience") or []:
#         head = f"Experience: {job.get('job_title') or ''} at {job.get('company') or ''}"
#         duration = f" ({job['duration']})" if job.get("duration") else ""
#         lines.append(head + duration + ". " + " ".join(job.get("responsibilities") or []))
#     for edu in profile.get("education") or []:
#         if edu.get("degree"):
#             lines.append(f"Education: {edu['degree']}")
#     if profile.get("projects"):
#         lines.append("Projects: " + "; ".join(profile["projects"]))
#     if profile.get("certifications"):
#         lines.append("Certifications: " + "; ".join(profile["certifications"]))
#     return "\n".join(lines)[:MAX_CHARS]


# def job_to_text(job: dict[str, Any]) -> str:
#     fields = [
#         ("Title", job.get("title")),
#         ("Department", job.get("department")),
#         ("Job type", job.get("jobType")),
#         ("Description", job.get("description")),
#         ("Responsibilities", job.get("responsibilities")),
#         ("Required education", job.get("education")),
#         ("Required experience", job.get("experience")),
#         ("Required skills", ", ".join(job.get("skills") or [])),
#     ]
#     return "\n".join(f"{k}: {v}" for k, v in fields if v)[:MAX_CHARS]


# def text_hash(text: str) -> str:
#     return hashlib.sha256(f"{embedding_model()}|{DIMS}|{text}".encode()).hexdigest()


# # ---------- vector math ----------

# def normalize(vec: list[float]) -> list[float]:
#     norm = math.sqrt(sum(x * x for x in vec))
#     return [x / norm for x in vec] if norm else vec


# def cosine(a: list[float], b: list[float]) -> float:
#     """Vectors are stored L2-normalized, so cosine is just the dot product."""
#     return sum(x * y for x, y in zip(a, b))


# def similarity_to_score(sim: float) -> float:
#     scaled = (sim - SIM_FLOOR) / (SIM_CEIL - SIM_FLOOR)
#     return round(100 * min(1.0, max(0.0, scaled)), 1)


# # ---------- Gemini call ----------

# def embed_texts(texts: list[str], task_type: str) -> list[list[float]]:
#     from google import genai
#     from google.genai import types

#     api_key = os.getenv("GEMINI_API_KEY")
#     if not api_key:
#         raise RuntimeError("GEMINI_API_KEY is missing.")
#     client = genai.Client(api_key=api_key)

#     vectors: list[list[float]] = []
#     for i in range(0, len(texts), BATCH_SIZE):
#         response = client.models.embed_content(
#             model=embedding_model(),
#             contents=texts[i : i + BATCH_SIZE],
#             config=types.EmbedContentConfig(
#                 task_type=task_type, output_dimensionality=DIMS
#             ),
#         )
#         # Truncated (768) vectors are not unit length, so normalize them.
#         vectors += [normalize(list(e.values)) for e in response.embeddings]
#     return vectors


# # ---------- Firestore cache ----------

# def _save(db, collection: str, doc_id: str, vector: list[float], digest: str) -> None:
#     db.collection(collection).document(doc_id).set(
#         {
#             "id": doc_id,
#             "textHash": digest,
#             "model": embedding_model(),
#             "dims": DIMS,
#             "embedding": vector,
#             "updatedAt": firestore.SERVER_TIMESTAMP,
#         }
#     )


# def get_or_create_candidate_vectors(
#     db, profiles: dict[str, dict[str, Any]]
# ) -> dict[str, list[float]]:
#     """Return {uid: vector}, embedding only profiles that are new or changed."""
#     existing = {
#         d.id: d.to_dict() or {} for d in db.collection("candidate_embeddings").stream()
#     }
#     vectors: dict[str, list[float]] = {}
#     todo: list[tuple[str, str, str]] = []

#     for uid, profile in profiles.items():
#         text = profile_to_text(profile)
#         if not text.strip():
#             continue
#         digest = text_hash(text)
#         cached = existing.get(uid)
#         if cached and cached.get("textHash") == digest and cached.get("embedding"):
#             vectors[uid] = cached["embedding"]
#         else:
#             todo.append((uid, text, digest))

#     if todo:
#         new_vectors = embed_texts([t for _, t, _ in todo], "RETRIEVAL_DOCUMENT")
#         for (uid, _, digest), vec in zip(todo, new_vectors):
#             _save(db, "candidate_embeddings", uid, vec, digest)
#             vectors[uid] = vec
#     return vectors


# def get_or_create_job_vector(db, job_id: str, job: dict[str, Any]) -> list[float]:
#     text = job_to_text(job)
#     if not text.strip():
#         raise ValueError("Job has no content to embed.")
#     digest = text_hash(text)

#     snap = db.collection("job_embeddings").document(job_id).get()
#     cached = snap.to_dict() if snap.exists else None
#     if cached and cached.get("textHash") == digest and cached.get("embedding"):
#         return cached["embedding"]

#     vec = embed_texts([text], "RETRIEVAL_QUERY")[0]
#     _save(db, "job_embeddings", job_id, vec, digest)
#     return vec