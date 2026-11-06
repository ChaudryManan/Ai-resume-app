from app.schemas.resume_schema import CandidateProfile


class JobProfile(CandidateProfile):
    """
    A job described with the exact same fields as CandidateProfile.

    Field meaning on the job side:
      professional_title   -> job title
      professional_summary -> job description
      technical_skills     -> required skills
      total_experience     -> required experience
      education            -> required education
      work_experience      -> one entry: job title + responsibilities

    Fields that only make sense for a person (full_name, email, phone,
    certifications, projects, languages) stay empty so the shape is
    identical to a screened resume.
    """

    department: str | None = None
    job_type: str | None = None
    salary: str | None = None
