import os
from datetime import date

os.environ.setdefault("GEMINI_API_KEY", "test-key")

from app.schemas.job_matching_schema import (
    JobRequirements,
    LLMJudgement,
    RoleRelevance,
    ScoreBreakdown,
    ScoredAspect,
    SkillAssessment,
)
from app.services import matching_service as ms


def judgement(skills=None, relevance=None, edu="bachelor"):
    return LLMJudgement(
        skills=[SkillAssessment(skill=s, level=l) for s, l in (skills or {}).items()],
        job_relevance=[RoleRelevance(index=i, relevance=r) for i, r in (relevance or {}).items()],
        highest_education_level=edu,
        education_field_relevance=ScoredAspect(score=90),
        title_fit=ScoredAspect(score=80),
        impact_and_growth=ScoredAspect(score=60),
    )


def requirements(**kwargs):
    base = dict(job_title="AI Engineer", must_have_skills=["Python", "NumPy"])
    return JobRequirements(**{**base, **kwargs})


# ---------- dates ----------
def test_structured_month_dates_are_used():
    assert ms._parse_point("2021-05") == (2021, 5)
    assert ms._parse_point("Mar 2021") == (2021, 3)
    assert ms._parse_point("2021") == (2021, 6)
    assert ms._parse_point("present") == (date.today().year, date.today().month)


def test_month_name_containing_to_is_not_split():
    # "October" used to be split at the letters "to"
    start, end = ms._interval("October 2020 - December 2021")
    assert end - start == 14


def test_experience_merges_overlapping_jobs():
    profile = {"work_experience": [
        {"start_date": "2020-01", "end_date": "2022-01"},
        {"start_date": "2021-01", "end_date": "2023-01"},
    ]}
    total, _ = ms.experience_years(profile, judgement())
    assert total == 3.0  # not 4.0


def test_relevant_years_use_job_relevance():
    profile = {"work_experience": [
        {"start_date": "2020-01", "end_date": "2022-01"},
        {"start_date": "2022-01", "end_date": "2024-01"},
    ]}
    total, relevant = ms.experience_years(profile, judgement(relevance={0: 0.0, 1: 1.0}))
    assert (total, relevant) == (4.0, 2.0)


def test_text_duration_is_used_when_dates_are_missing():
    profile = {"work_experience": [{"duration": "2 years"}, {"duration": "6 months"}]}
    total, _ = ms.experience_years(profile, judgement())
    assert total == 2.5


def test_no_work_experience_means_zero_years():
    assert ms.experience_years({"work_experience": []}, judgement()) == (0.0, 0)


# ---------- scores ----------
def test_entry_level_job_does_not_give_fresh_graduates_zero():
    entry = requirements(min_years_experience=0)
    assert ms.score_experience(0, entry) == 70
    assert ms.score_experience(2, entry) == 100


def test_experience_score_scales_below_minimum_and_caps_at_100():
    need = requirements(min_years_experience=4, preferred_years_experience=6)
    assert ms.score_experience(2, need) == 35
    assert ms.score_experience(4, need) == 70
    assert ms.score_experience(10, need) == 100


def test_skill_names_match_even_with_different_spelling():
    req = requirements(must_have_skills=["Node.js", "C++"])
    j = judgement(skills={"node.js": "expert", "C++ ": "used"})
    score, coverage, matched, missing = ms.score_skills(req, j)
    assert matched == ["Node.js", "C++"] and missing == []
    assert round(coverage, 2) == 0.85


def test_missing_skills_are_reported():
    score, coverage, matched, missing = ms.score_skills(
        requirements(), judgement(skills={"Python": "proficient"})
    )
    assert matched == ["Python"] and missing == ["NumPy"]


def test_education_level_gap():
    req = requirements(min_education_level="master")
    assert ms.score_education(req, judgement(edu="master")) == 96
    assert ms.score_education(req, judgement(edu="bachelor")) == 0.6 * 65 + 36


def test_semantic_is_stretched_not_near_100_for_everything():
    assert ms.score_semantic(0.78) == 40  # an unrelated tech resume
    assert ms.score_semantic(0.95) == 100
    assert ms.score_semantic(0.5) == 0
    assert ms.score_semantic(None) is None


def test_final_score_ignores_missing_semantic_instead_of_counting_zero():
    b = ScoreBreakdown(skills=80, experience=80, title=80, education=80, impact=80, semantic=None)
    score, knocked, _ = ms.final_score(b, None, 0.8, 3, requirements())
    assert round(score, 1) == 80.0 and not knocked


def test_knockout_caps_score_but_keeps_candidate():
    b = ScoreBreakdown(skills=10, experience=90, title=90, education=90, impact=90, semantic=90)
    score, knocked, reason = ms.final_score(b, None, 0.1, 3, requirements())
    assert score <= 45 and knocked and "must-have" in reason


def test_per_job_weights_override_defaults():
    b = ScoreBreakdown(skills=100, experience=0, title=0, education=0, impact=0, semantic=0)
    default, _, _ = ms.final_score(b, None, 1.0, 3, requirements())
    heavy, _, _ = ms.final_score(b, {"skills": 0.9}, 1.0, 3, requirements())
    assert heavy > default


def test_job_text_contains_the_form_fields():
    text = ms._job_text({
        "title": "AI Engineer", "skills": ["python", "numpy"],
        "experience": "1-2 Years", "education": "Bachelor's Degree",
        "responsibilities": "Build models",
    })
    assert "Required skills: python, numpy" in text
    assert "Required experience: 1-2 Years" in text
    assert "Responsibilities: Build models" in text
