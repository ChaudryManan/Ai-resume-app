import os

os.environ.setdefault("GEMINI_API_KEY", "test-key")

from app.schemas.job_schema import JobProfile
from app.schemas.resume_schema import CandidateProfile
from app.services.gemini_service import build_job_matching_chunks
from app.services.job_embedding_service import build_job_profile

JOB = {
    "title": "Flutter Developer",
    "department": "Engineering",
    "jobType": "Full Time",
    "location": "Lahore",
    "salary": "100000",
    "description": "Build mobile apps.",
    "responsibilities": "- Write clean code\n2. Review pull requests\n\n",
    "education": "Bachelor's Degree",
    "experience": "1-2 Years",
    "skills": ["Flutter", " Dart ", "flutter", ""],
}


def test_job_profile_has_every_candidate_profile_field():
    assert set(CandidateProfile.model_fields) <= set(JobProfile.model_fields)


def test_job_profile_maps_form_fields():
    profile = build_job_profile(JOB).model_dump()

    assert profile["professional_title"] == "Flutter Developer"
    assert profile["professional_summary"] == "Build mobile apps."
    assert profile["technical_skills"] == ["Flutter", "Dart"]
    assert profile["total_experience"] == "1-2 Years"
    assert profile["education"][0]["degree"] == "Bachelor's Degree"
    assert profile["work_experience"][0]["responsibilities"] == [
        "Write clean code",
        "Review pull requests",
    ]


def test_job_chunks_use_the_same_labels_as_resume_chunks():
    chunks = build_job_matching_chunks(build_job_profile(JOB).model_dump())
    headers = [chunk.split(":", 1)[0] for chunk in chunks]

    assert headers == [
        "Professional Profile",
        "Technical Skills",
        "Total Professional Experience",
        "Work Experience",
        "Education Qualification",
    ]
    joined = "\n".join(chunks)
    assert "Lahore" not in joined and "100000" not in joined


def test_empty_job_gives_no_chunks():
    assert build_job_matching_chunks(build_job_profile({}).model_dump()) == []
