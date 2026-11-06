import re

from app.schemas.job_schema import JobProfile
from app.schemas.resume_schema import Education, WorkExperience

_BULLET_PREFIX = re.compile(r"^\s*(?:[-*\u2022\u2013]|\d+[.)])\s*")


def _clean(value) -> str | None:
    if not isinstance(value, str):
        return None
    value = value.strip()
    return value or None


def _split_lines(text) -> list[str]:
    """Turn a multi-line responsibilities text into one item per line."""
    if not isinstance(text, str):
        return []

    lines = []
    for raw_line in text.splitlines():
        line = _BULLET_PREFIX.sub("", raw_line).strip()
        if line:
            lines.append(line)
    return lines


def _clean_skills(skills) -> list[str]:
    cleaned: list[str] = []
    seen: set[str] = set()

    for skill in skills or []:
        skill = _clean(skill)
        if skill and skill.lower() not in seen:
            seen.add(skill.lower())
            cleaned.append(skill)

    return cleaned


def build_job_profile(job: dict) -> JobProfile:
    """
    Convert a Firestore job document into a JobProfile, which has the
    same shape as the CandidateProfile produced by /api/resumes/screen.
    """
    title = _clean(job.get("title"))
    responsibilities = _split_lines(job.get("responsibilities"))
    education = _clean(job.get("education"))

    return JobProfile(
        professional_title=title,
        professional_summary=_clean(job.get("description")),
        location=_clean(job.get("location")),
        total_experience=_clean(job.get("experience")),
        technical_skills=_clean_skills(job.get("skills")),
        education=[Education(degree=education)] if education else [],
        work_experience=(
            [WorkExperience(job_title=title, responsibilities=responsibilities)]
            if title or responsibilities
            else []
        ),
        department=_clean(job.get("department")),
        job_type=_clean(job.get("jobType")),
        salary=_clean(job.get("salary")),
    )
