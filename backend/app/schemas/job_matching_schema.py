from typing import Literal

from pydantic import BaseModel, Field

EducationLevel = Literal[
    "none", "high_school", "diploma", "bachelor", "master", "phd"
]
SkillLevelName = Literal["none", "mentioned", "used", "proficient", "expert"]


# ---------- Job -> structured requirements (LLM output) ----------
class JobRequirements(BaseModel):
    job_title: str
    title_aliases: list[str] = Field(default_factory=list)
    seniority: str | None = None
    must_have_skills: list[str] = Field(default_factory=list)
    nice_to_have_skills: list[str] = Field(default_factory=list)
    min_years_experience: float = 0
    preferred_years_experience: float | None = None
    min_education_level: EducationLevel = "none"
    relevant_education_fields: list[str] = Field(default_factory=list)


# ---------- One candidate vs one job (LLM output) ----------
class SkillAssessment(BaseModel):
    skill: str = Field(description="Copy the skill name exactly as given in the job requirements.")
    level: SkillLevelName
    evidence: str | None = None


class RoleRelevance(BaseModel):
    index: int
    relevance: float = Field(description="0 to 1: how similar this role is to the target job.")


class ScoredAspect(BaseModel):
    score: int = Field(description="0 to 100.")
    reason: str = ""


class LLMJudgement(BaseModel):
    skills: list[SkillAssessment] = Field(default_factory=list)
    job_relevance: list[RoleRelevance] = Field(default_factory=list)
    highest_education_level: EducationLevel = "none"
    education_field_relevance: ScoredAspect
    title_fit: ScoredAspect
    impact_and_growth: ScoredAspect
    strengths: list[str] = Field(default_factory=list)
    gaps: list[str] = Field(default_factory=list)
    red_flags: list[str] = Field(default_factory=list)
    summary: str = ""


# ---------- Final result ----------
class ScoreBreakdown(BaseModel):
    skills: float = 0
    experience: float = 0
    title: float = 0
    education: float = 0
    impact: float = 0
    semantic: float | None = None  # None when the job has no stored vectors


class CandidateMatch(BaseModel):
    candidate_id: str
    candidate_name: str | None = None
    resume_file_name: str | None = None
    overall_score: float
    breakdown: ScoreBreakdown
    must_have_coverage: float = 0
    matched_skills: list[str] = Field(default_factory=list)
    missing_skills: list[str] = Field(default_factory=list)
    relevant_years: float = 0
    total_years: float = 0
    strengths: list[str] = Field(default_factory=list)
    gaps: list[str] = Field(default_factory=list)
    red_flags: list[str] = Field(default_factory=list)
    summary: str = ""
    knocked_out: bool = False
    knockout_reason: str | None = None


class MatchResponse(BaseModel):
    job_id: str
    evaluated: int
    failed: int = 0
    skipped_no_profile: int = 0
    results: list[CandidateMatch] = Field(default_factory=list)
