MAX_CHUNK_CHARACTERS = 1800
CHUNK_OVERLAP_CHARACTERS = 200


def chunk_resume_text(
    text: str,
    max_characters: int = MAX_CHUNK_CHARACTERS,
    overlap_characters: int = CHUNK_OVERLAP_CHARACTERS,
) -> list[str]:
    if max_characters <= 0:
        raise ValueError("max_characters must be greater than zero.")

    if overlap_characters < 0 or overlap_characters >= max_characters:
        raise ValueError(
            "overlap_characters must be non-negative and smaller "
            "than max_characters."
        )

    normalized_text = " ".join(text.split())
    if not normalized_text:
        return []

    chunks: list[str] = []
    start = 0

    while start < len(normalized_text):
        end = min(start + max_characters, len(normalized_text))

        if end < len(normalized_text):
            word_boundary = normalized_text.rfind(" ", start, end)
            if word_boundary > start:
                end = word_boundary

        chunk = normalized_text[start:end].strip()
        if chunk:
            chunks.append(chunk)

        if end >= len(normalized_text):
            break

        next_start = max(start + 1, end - overlap_characters)
        next_word_boundary = normalized_text.find(" ", next_start, end)
        if next_word_boundary >= 0:
            next_start = next_word_boundary + 1

        start = next_start

    return chunks
