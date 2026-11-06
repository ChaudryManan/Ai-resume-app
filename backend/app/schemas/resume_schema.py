
from pydantic import BaseModel, Field


class Education(BaseModel):
    degree: str | None = None
    institution: str | None = None
    graduation_year: str | None = None


class WorkExperience(BaseModel):
    company: str | None = None
    job_title: str | None = None
    duration: str | None = None
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

    work_experience: list[WorkExperience] = Field(
        default_factory=list
    )

    technical_skills: list[str] = Field(default_factory=list)

    certifications: list[str] = Field(default_factory=list)

    projects: list[str] = Field(default_factory=list)

    languages: list[str] = Field(default_factory=list)
