from app.services.job_embedding_service import build_job_chunks


def test_builds_overview_requirements_and_responsibilities():
    job = {
        "title": "Flutter Developer",
        "department": "Engineering",
        "jobType": "Full Time",
        "location": "Lahore",
        "salary": "100000",
        "description": "Build mobile apps.",
        "responsibilities": "Write clean code.",
        "education": "Bachelor's Degree",
        "experience": "1-2 Years",
        "skills": ["Flutter", " Dart ", ""],
    }

    chunks = build_job_chunks(job)

    assert len(chunks) == 3
    assert "Flutter Developer" in chunks[0]
    assert "Required Skills: Flutter, Dart" in chunks[1]
    assert chunks[2].startswith("Job Responsibilities:")
    assert all("Lahore" not in c and "100000" not in c for c in chunks)


def test_empty_job_returns_no_chunks():
    assert build_job_chunks({}) == []


def test_long_description_is_split():
    chunks = build_job_chunks({"title": "X", "description": "word " * 1000})
    assert len(chunks) > 1
