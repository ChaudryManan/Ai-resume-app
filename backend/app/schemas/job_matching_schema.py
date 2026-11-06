
from pydantic import BaseModel, Field


# Information about the job we want to match candidates against
class JobRequirements(BaseModel):

    job_id: str

    title: str

    required_skills: list[str] = Field(
        default_factory=list
    )

    minimum_experience_months: int = 0

    education_requirements: list[str] = Field(
        default_factory=list
    )

    other_requirements: str | None = None


# Individual matching scores
class MatchScores(BaseModel):

    skill_score: float = 0

    experience_score: float = 0

    education_score: float = 0

    other_requirements_score: float = 0

    overall_score: float = 0


# Matching result for one candidate
class CandidateMatchResult(BaseModel):

    candidate_uid: str

    candidate_name: str | None = None

    job_id: str

    scores: MatchScores

    matched_skills: list[str] = Field(
        default_factory=list
    )

    missing_skills: list[str] = Field(
        default_factory=list
    )

    explanation: str | None = None

    matching_status: str = "completed"
