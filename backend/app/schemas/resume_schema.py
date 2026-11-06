"""backend/app/schemas/resume_schema.py  (replace your file)

Changes vs your version:
  + Education.field_of_study   -> lets the matcher judge degree relevance (CS vs unrelated)
  + WorkExperience.start_date / end_date -> real experience maths instead of parsing "duration" text
"""
from pydantic import BaseModel, Field


class Education(BaseModel):
    degree: str | None = None
    field_of_study: str | None = Field(
        default=None, description="Major/subject, e.g. 'Computer Science'. Null if not stated.")
    institution: str | None = None
    graduation_year: str | None = None


class WorkExperience(BaseModel):
    company: str | None = None
    job_title: str | None = None
    start_date: str | None = Field(
        default=None, description="YYYY-MM, or YYYY if the month is not stated. Null if not stated.")
    end_date: str | None = Field(
        default=None, description="YYYY-MM, YYYY, or 'present' if this is the current job. Null if not stated.")
    duration: str | None = None  # kept as the original text, used as a fallback
    responsibilities: list[str] = Field(default_factory=list)


class CandidateProfile(BaseModel):
    full_name: str | None = None
    professional_title: str | None = None

    email: str | None = None
    phone: str | None = None
    location: str | None = None

    professional_summary: str | None = None

    education: list[Education] = Field(default_factory=list)

    total_experience: str | None = None

    work_experience: list[WorkExperience] = Field(default_factory=list)

    technical_skills: list[str] = Field(default_factory=list)

    certifications: list[str] = Field(default_factory=list)

    projects: list[str] = Field(default_factory=list)

    languages: list[str] = Field(default_factory=list)