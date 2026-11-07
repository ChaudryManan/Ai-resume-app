import copy
import json
import os
from datetime import datetime, timedelta, timezone
from unittest.mock import AsyncMock, MagicMock, patch

os.environ.setdefault("GEMINI_API_KEY", "test-key")

from fastapi import FastAPI
from fastapi.testclient import TestClient
from firebase_admin import firestore

from app.routers.job_embeddings import router as job_embeddings_router
from app.routers.candidates import router as candidates_router
from app.routers.matching import router as matching_router
from app.services import matching_service as ms


# ---------- a tiny in-memory Firestore ----------
class Snap:
    def __init__(self, ref, data):
        self.reference, self.id, self._data = ref, ref.id, data

    @property
    def exists(self):
        return self._data is not None

    def to_dict(self):
        return copy.deepcopy(self._data) if self._data is not None else None


class Query:
    def __init__(self, store, items):
        self.store, self.items = store, items

    def stream(self):
        return [Snap(DocRef(self.store, p), d) for p, d in self.items]

    def where(self, *args, filter=None):
        keep = [(p, d) for p, d in self.items if d.get(filter.field_path) == filter.value]
        return Query(self.store, keep)

    def order_by(self, field):
        return Query(self.store, sorted(self.items, key=lambda item: item[1][field]))

    def limit(self, count):
        return Query(self.store, self.items[:count])


class ColRef(Query):
    def __init__(self, store, path):
        children = [
            (p, d) for p, d in store.items()
            if p.startswith(path + "/") and "/" not in p[len(path) + 1:]
        ]
        super().__init__(store, children)
        self.path = path

    def document(self, doc_id):
        return DocRef(self.store, f"{self.path}/{doc_id}")


class DocRef:
    def __init__(self, store, path):
        self.store, self.path, self.id = store, path, path.split("/")[-1]

    def get(self):
        return Snap(self, self.store.get(self.path))

    def set(self, data, merge=False):
        data = {
            k: datetime.now(timezone.utc) if v is firestore.SERVER_TIMESTAMP else v
            for k, v in copy.deepcopy(data).items()
        }
        self.store[self.path] = {**self.store.get(self.path, {}), **data} if merge else data

    def collection(self, name):
        return ColRef(self.store, f"{self.path}/{name}")


class Batch:
    def __init__(self):
        self.ops = []

    def set(self, ref, data):
        self.ops.append(lambda: ref.set(data))

    def delete(self, ref):
        self.ops.append(lambda: ref.store.pop(ref.path, None))

    def commit(self):
        for op in self.ops:
            op()


class FakeFirestore:
    def __init__(self):
        self.store = {}

    def collection(self, name):
        return ColRef(self.store, name)

    def get_all(self, refs):
        return [ref.get() for ref in refs]

    def batch(self):
        return Batch()


# ---------- test data ----------
JOB = {
    "title": "AI Engineer", "department": "AI", "jobType": "Full Time",
    "description": "Build ML systems", "responsibilities": "Train and ship models",
    "skills": ["Python", "NumPy"], "experience": "1-2 Years", "education": "Bachelor's Degree",
}
REQUIREMENTS = {
    "job_title": "AI Engineer", "must_have_skills": ["Python", "NumPy"],
    "nice_to_have_skills": [], "min_years_experience": 1,
    "preferred_years_experience": 3, "min_education_level": "bachelor",
}


def candidate(company, title, skills):
    return {
        "uid": "x", "resumeFileName": "cv.pdf",
        "profile": {
            "full_name": "Secret Name", "email": "secret@mail.com", "phone": "0300",
            "professional_title": title,
            "technical_skills": skills,
            "work_experience": [{"company": company, "job_title": title,
                                 "start_date": "2021-03", "end_date": "2023-03",
                                 "responsibilities": ["built things"]}],
            "education": [{"degree": "BS", "field_of_study": "Computer Science"}],
        },
    }


JUDGEMENTS = {
    "DeepLabs": {  # strong AI candidate
        "skills": [{"skill": "Python", "level": "proficient"}, {"skill": "NumPy", "level": "used"}],
        "job_relevance": [{"index": 0, "relevance": 0.9}], "highest_education_level": "bachelor",
        "education_field_relevance": {"score": 90}, "title_fit": {"score": 85},
        "impact_and_growth": {"score": 70}, "strengths": ["ML depth"], "summary": "Strong fit",
    },
    "AppWorks": {  # Flutter developer
        "skills": [{"skill": "Python", "level": "none"}, {"skill": "NumPy", "level": "none"}],
        "job_relevance": [{"index": 0, "relevance": 0.1}], "highest_education_level": "bachelor",
        "education_field_relevance": {"score": 70}, "title_fit": {"score": 20},
        "impact_and_growth": {"score": 50}, "gaps": ["No ML"], "summary": "Weak fit",
    },
}


class Env:
    def __init__(self):
        self.db = FakeFirestore()
        self.db.store["users/admin1"] = {"role": "admin"}
        self.db.store["users/user1"] = {"role": "user"}
        self.db.store["jobs/J1"] = copy.deepcopy(JOB)
        self.db.store["candidate_profiles/A"] = candidate("DeepLabs", "ML Engineer", ["Python", "NumPy"])
        self.db.store["candidate_profiles/B"] = candidate("AppWorks", "Flutter Dev", ["Flutter"])
        self.db.store["candidate_profiles/C"] = candidate("BrokenCo", "Dev", ["Python"])
        self.db.store["candidate_profiles/D"] = {"uid": "D", "screening_status": "pending"}  # no profile
        self.db.store["resumes/A"] = {"storagePath": "A/123_cv.pdf", "bucket": "resumes", "fileName": "cv.pdf"}
        self.prompts, self.requirement_calls = [], 0

        async def generate(model, contents, config):
            if "<job_posting>" in contents:
                self.requirement_calls += 1
                return MagicMock(text=json.dumps(REQUIREMENTS))
            self.prompts.append(contents)
            for marker, answer in JUDGEMENTS.items():
                if marker in contents:
                    return MagicMock(text=json.dumps(answer))
            raise RuntimeError("Gemini unavailable")

        gemini = MagicMock()
        gemini.aio.models.generate_content = AsyncMock(side_effect=generate)

        rpc = MagicMock()
        rpc.execute.return_value.data = [
            {"user_id": "A", "profile_score": 0.85, "skills_score": 0.88, "work_score": 0.82},
            {"user_id": "B", "profile_score": 0.72, "skills_score": 0.70, "work_score": 0.0},
        ]
        self.supabase = MagicMock()
        self.supabase.rpc.return_value = rpc
        self.supabase.storage.from_.return_value.create_signed_url.return_value = {
            "signedURL": "https://files.example/sign/abc", "signedUrl": "https://files.example/sign/abc"}

        app = FastAPI()
        app.include_router(job_embeddings_router)
        app.include_router(matching_router)
        app.include_router(candidates_router)
        self.client = TestClient(app)
        self.headers = {"Authorization": "Bearer t"}
        self.uid = "admin1"

        self.patches = [
            patch.object(firestore, "client", return_value=self.db),
            patch("app.dependencies.auth.auth.verify_id_token", side_effect=lambda t: {"uid": self.uid}),
            patch.object(ms, "_gemini", gemini),
            patch.object(ms, "get_supabase", return_value=self.supabase),
            patch("app.routers.job_embeddings._supabase", return_value=self.supabase),
            patch("app.routers.candidates.get_supabase", return_value=self.supabase),
            patch("app.routers.job_embeddings.embed_resume_chunks",
                  side_effect=lambda chunks: [[0.1] * 768 for _ in chunks]),
        ]

    def __enter__(self):
        for p in self.patches:
            p.start()
        return self

    def __exit__(self, *exc):
        for p in self.patches:
            p.stop()


# ---------- tests ----------
def test_creating_a_job_embeds_it_then_matches_all_resumes():
    with Env() as env:
        response = env.client.post("/api/jobs/J1/embed", headers=env.headers)
        assert response.status_code == 200
        assert response.json()["matching"] == "started"

        job = env.db.store["jobs/J1"]
        assert job["embeddingStatus"] == "completed"
        assert job["matchStatus"] == "completed"
        assert (job["matchEvaluated"], job["matchFailed"], job["matchSkippedNoProfile"]) == (2, 1, 1)

        matches = env.db.store
        a, b = matches["jobs/J1/matches/A"], matches["jobs/J1/matches/B"]
        assert (a["rank"], b["rank"]) == (1, 2)
        assert "jobs/J1/matches/C" not in matches and "jobs/J1/matches/D" not in matches

        # A: skills 80, experience 82, title 85, education 96, semantic 75, impact 70
        assert abs(a["overall_score"] - 81.6) < 0.1
        assert a["relevant_years"] == 1.8 and a["total_years"] == 2.0
        assert a["matched_skills"] == ["Python", "NumPy"] and a["candidate_name"] == "Secret Name"

        # B: has none of the must-have skills -> capped and flagged
        assert b["knocked_out"] and b["overall_score"] <= 45
        assert b["missing_skills"] == ["Python", "NumPy"]


def test_judge_sees_the_resume_but_not_the_identity():
    with Env() as env:
        env.client.post("/api/jobs/J1/embed", headers=env.headers)
        prompt = next(p for p in env.prompts if "DeepLabs" in p)
        assert "Secret Name" not in prompt and "secret@mail.com" not in prompt and "0300" not in prompt
        assert '"index": 0' in prompt and "built things" in prompt  # profile was unwrapped


def test_matching_can_be_switched_off_on_the_embed_call():
    with Env() as env:
        response = env.client.post("/api/jobs/J1/embed?match=false", headers=env.headers)
        assert response.json()["matching"] == "skipped"
        assert "matchStatus" not in env.db.store["jobs/J1"]


def test_rematch_replaces_old_results_and_reuses_cached_requirements():
    with Env() as env:
        env.db.store["jobs/J1/matches/GONE"] = {"candidate_id": "GONE", "rank": 9}
        first = env.client.post("/api/jobs/J1/match", headers=env.headers)
        second = env.client.post("/api/jobs/J1/match", headers=env.headers)

        assert first.status_code == second.status_code == 200
        assert "jobs/J1/matches/GONE" not in env.db.store
        assert [r["candidate_id"] for r in second.json()["results"]] == ["A", "B"]
        assert env.requirement_calls == 1  # extracted once, then cached on the job


def test_get_matches_returns_status_and_ranked_results():
    with Env() as env:
        env.client.post("/api/jobs/J1/match", headers=env.headers)
        data = env.client.get("/api/jobs/J1/matches", headers=env.headers).json()
        assert data["match_status"] == "completed" and data["matched_at"]
        assert [r["candidate_id"] for r in data["results"]] == ["A", "B"]


def test_works_without_semantic_scores():
    with Env() as env:
        env.supabase.rpc.return_value.execute.side_effect = RuntimeError("db down")
        response = env.client.post("/api/jobs/J1/match", headers=env.headers)
        assert response.status_code == 200
        assert response.json()["results"][0]["breakdown"]["semantic"] is None


def test_only_applicants_are_matched_when_requested():
    with Env() as env:
        env.db.store["applications/B_J1"] = {"uid": "B", "jobId": "J1"}
        env.db.store["applications/A_J2"] = {"uid": "A", "jobId": "J2"}  # other job
        data = env.client.post("/api/jobs/J1/match?applicants_only=true", headers=env.headers).json()
        assert [r["candidate_id"] for r in data["results"]] == ["B"]


def test_non_admin_and_unknown_job_are_rejected():
    with Env() as env:
        env.uid = "user1"
        assert env.client.post("/api/jobs/J1/match", headers=env.headers).status_code == 403
        assert env.client.get("/api/jobs/J1/matches", headers=env.headers).status_code == 403
        assert env.client.post("/api/jobs/J1/embed", headers=env.headers).status_code == 403

        env.uid = "admin1"
        assert env.client.post("/api/jobs/NOPE/match", headers=env.headers).status_code == 404
        assert "jobs/NOPE" not in env.db.store  # no empty job document is created
        assert env.client.post("/api/jobs/J1/match").status_code in (401, 403)  # no token


def test_total_llm_failure_is_recorded_on_the_job():
    with Env() as env:
        env.db.store["jobs/J1"]["skills"] = []  # force new requirements extraction
        ms_gemini = ms._gemini
        ms_gemini.aio.models.generate_content.side_effect = RuntimeError("quota")
        response = env.client.post("/api/jobs/J1/match", headers=env.headers)
        assert response.status_code == 500
        job = env.db.store["jobs/J1"]
        assert job["matchStatus"] == "failed" and "quota" in job["matchError"]


# ---------- admin screen: eligibility, re-run button, resume link ----------
def test_candidates_are_labelled_and_carry_contact_info():
    with Env() as env:
        data = env.client.post("/api/jobs/J1/match", headers=env.headers).json()
        a, b = data["results"]
        assert a["eligibility"] == "highly_eligible" and b["eligibility"] == "low_match"
        assert (a["candidate_email"], a["candidate_title"]) == ("secret@mail.com", "ML Engineer")


def test_background_rerun_returns_at_once_and_saves_the_new_ranking():
    with Env() as env:
        env.db.store["jobs/J1/matches/GONE"] = {"candidate_id": "GONE", "rank": 9}
        response = env.client.post("/api/jobs/J1/match?background=true", headers=env.headers)
        assert response.json() == {"status": "started", "job_id": "J1"}

        job = env.db.store["jobs/J1"]
        assert job["matchStatus"] == "completed" and job["matchStartedAt"]
        assert "jobs/J1/matches/GONE" not in env.db.store
        assert env.db.store["jobs/J1/matches/A"]["rank"] == 1


def test_second_click_while_running_is_rejected_but_a_stale_run_is_not():
    with Env() as env:
        job = env.db.store["jobs/J1"]
        job.update(matchStatus="processing", matchStartedAt=datetime.now(timezone.utc))
        busy = env.client.post("/api/jobs/J1/match?background=true", headers=env.headers)
        assert busy.status_code == 409

        job["matchStartedAt"] = datetime.now(timezone.utc) - timedelta(minutes=11)  # crashed run
        again = env.client.post("/api/jobs/J1/match?background=true", headers=env.headers)
        assert again.status_code == 200 and env.db.store["jobs/J1"]["matchStatus"] == "completed"


def test_background_rerun_of_unknown_job_is_404_and_creates_nothing():
    with Env() as env:
        response = env.client.post("/api/jobs/NOPE/match?background=true", headers=env.headers)
        assert response.status_code == 404 and "jobs/NOPE" not in env.db.store


def test_results_saved_before_this_feature_still_load_with_a_label():
    with Env() as env:
        env.db.store["jobs/J1/matches/OLD"] = {  # no eligibility/email/title fields
            "candidate_id": "OLD", "overall_score": 66.0, "rank": 1,
            "breakdown": {"skills": 60, "experience": 60, "title": 60, "education": 60, "impact": 60},
            "scoredAt": datetime.now(timezone.utc),
        }
        data = env.client.get("/api/jobs/J1/matches", headers=env.headers).json()
        assert data["results"][0]["eligibility"] == "potential" and data["results"][0]["rank"] == 1
        assert data["thresholds"] == {"highly_eligible": 75, "potential": 60}
        assert data["job_title"] == "AI Engineer"


def test_admin_gets_a_resume_link():
    with Env() as env:
        data = env.client.get("/api/candidates/A/resume", headers=env.headers).json()
        assert data == {"url": "https://files.example/sign/abc", "file_name": "cv.pdf", "expires_in": 600}
        env.supabase.storage.from_.assert_called_with("resumes")
        env.supabase.storage.from_.return_value.create_signed_url.assert_called_with("A/123_cv.pdf", 600)


def test_resume_link_is_admin_only_and_validated():
    with Env() as env:
        env.uid = "user1"
        assert env.client.get("/api/candidates/A/resume", headers=env.headers).status_code == 403

        env.uid = "admin1"
        assert env.client.get("/api/candidates/B/resume", headers=env.headers).status_code == 404  # no resume doc

        env.db.store["resumes/B"] = {"storagePath": "SOMEONE_ELSE/x.pdf", "bucket": "resumes"}
        assert env.client.get("/api/candidates/B/resume", headers=env.headers).status_code == 403

        env.db.store["resumes/B"] = {"storagePath": "B/x.pdf", "bucket": "other"}
        assert env.client.get("/api/candidates/B/resume", headers=env.headers).status_code == 400


def test_resume_link_failures_are_clean_errors():
    with Env() as env:
        sign = env.supabase.storage.from_.return_value.create_signed_url
        sign.return_value = {"signedURL": None, "signedUrl": None}
        assert env.client.get("/api/candidates/A/resume", headers=env.headers).status_code == 404

        sign.side_effect = RuntimeError("storage down")
        assert env.client.get("/api/candidates/A/resume", headers=env.headers).status_code == 500
