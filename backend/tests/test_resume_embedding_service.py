import unittest

from app.services.resume_embedding_service import chunk_resume_text


class ChunkResumeTextTests(unittest.TestCase):
    def test_empty_text_returns_no_chunks(self):
        self.assertEqual(chunk_resume_text(" \n\t "), [])

    def test_chunks_respect_size_and_overlap(self):
        text = " ".join(f"word{index}" for index in range(100))
        chunks = chunk_resume_text(
            text,
            max_characters=80,
            overlap_characters=12,
        )

        self.assertGreater(len(chunks), 1)
        self.assertTrue(all(len(chunk) <= 80 for chunk in chunks))
        self.assertTrue(
            any(
                set(first.split()) & set(second.split())
                for first, second in zip(chunks, chunks[1:])
            )
        )

    def test_invalid_chunk_sizes_raise(self):
        with self.assertRaises(ValueError):
            chunk_resume_text("resume", max_characters=0)

        with self.assertRaises(ValueError):
            chunk_resume_text(
                "resume",
                max_characters=20,
                overlap_characters=20,
            )

    def test_single_long_word_is_split_without_data_loss(self):
        text = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWX"
        chunks = chunk_resume_text(
            text,
            max_characters=10,
            overlap_characters=2,
        )

        reconstructed = chunks[0]
        for previous, chunk in zip(chunks, chunks[1:]):
            overlap = max(
                size
                for size in range(1, min(len(previous), len(chunk)) + 1)
                if previous.endswith(chunk[:size])
            )
            reconstructed += chunk[overlap:]

        self.assertEqual(reconstructed, text)
        self.assertTrue(all(len(chunk) <= 10 for chunk in chunks))


if __name__ == "__main__":
    unittest.main()
