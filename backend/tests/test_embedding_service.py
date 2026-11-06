# import math

# from app.services.embedding_service import (
#     cosine, normalize, profile_to_text, similarity_to_score, text_hash,
# )


# def test_normalize_and_cosine():
#     a = normalize([3.0, 4.0])
#     assert math.isclose(sum(x * x for x in a), 1.0)
#     assert math.isclose(cosine(a, a), 1.0)
#     assert math.isclose(cosine(normalize([1, 0]), normalize([0, 1])), 0.0, abs_tol=1e-9)


# def test_profile_text_excludes_personal_details():
#     text = profile_to_text(
#         {"full_name": "Abdul", "email": "a@b.com", "phone": "0300",
#          "location": "RYK", "technical_skills": ["React"]}
#     )
#     assert "React" in text
#     for secret in ("Abdul", "a@b.com", "0300", "RYK"):
#         assert secret not in text


# def test_similarity_score_is_clamped():
#     assert similarity_to_score(0.1) == 0.0
#     assert similarity_to_score(0.99) == 100.0


# def test_hash_changes_with_text():
#     assert text_hash("a") != text_hash("b")