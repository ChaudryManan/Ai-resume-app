from pydantic import BaseModel, Field


class GenerateOfferRequest(BaseModel):
    candidate_id: str = Field(min_length=1)
    job_id: str = Field(min_length=1)
    salary: str = Field(min_length=1, max_length=200)
    benefits: list[str] = Field(default_factory=list)
    working_hours: str | None = Field(default=None, max_length=200)
    joining_date: str | None = Field(default=None, max_length=100)
    additional_terms: str | None = Field(default=None, max_length=3000)


class GeneratedOfferResponse(BaseModel):
    offer_id: str
    candidate_name: str
    candidate_email: str
    subject: str
    body: str
    status: str
