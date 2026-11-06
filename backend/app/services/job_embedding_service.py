from app.services.resume_embedding_service import chunk_resume_text


def _section_chunks(header: str, body: str) -> list[str]:
    """Prefix every piece of a long section with its header."""
    return [f"{header}\n{piece}" for piece in chunk_resume_text(body)]


def build_job_chunks(job: dict) -> list[str]:
    """
    Convert a Firestore job document into text chunks for embedding.

    Salary, location, status and admin identity are left out because
    they add noise to the semantic match between a job and a resume.
    """
    chunks: list[str] = []

    # 1. Overview
    title = (job.get("title") or "").strip()
    department = (job.get("department") or "").strip()
    job_type = (job.get("jobType") or "").strip()
    description = (job.get("description") or "").strip()

    if title or description:
        header_lines = ["Job Overview:"]
        if title:
            header_lines.append(f"Job Title: {title}")
        if department:
            header_lines.append(f"Department: {department}")
        if job_type:
            header_lines.append(f"Job Type: {job_type}")
        header = "\n".join(header_lines)

        if description:
            chunks.extend(
                _section_chunks(f"{header}\nJob Description:", description)
            )
        else:
            chunks.append(header)

    # 2. Requirements
    skills = [
        skill.strip()
        for skill in (job.get("skills") or [])
        if isinstance(skill, str) and skill.strip()
    ]
    education = (job.get("education") or "").strip()
    experience = (job.get("experience") or "").strip()

    if skills or education or experience:
        lines = ["Job Requirements:"]
        if skills:
            lines.append("Required Skills: " + ", ".join(skills))
        if education:
            lines.append(f"Education Required: {education}")
        if experience:
            lines.append(f"Experience Required: {experience}")
        chunks.append("\n".join(lines))

    # 3. Responsibilities
    responsibilities = (job.get("responsibilities") or "").strip()
    if responsibilities:
        chunks.extend(
            _section_chunks("Job Responsibilities:", responsibilities)
        )

    return chunks
