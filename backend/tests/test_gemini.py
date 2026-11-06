
from app.services.gemini_service import client, MODEL

try:
    response = client.models.generate_content(
        model=MODEL,
        contents="Return a short greeting."
    )

    print("Gemini API SUCCESS")
    print("Model:", MODEL)
    print("Response:", response.text)

except Exception as error:
    print("Gemini API FAILED")
    print("Error type:", type(error).__name__)
    print("Error message:", str(error))
    print("Error code:", getattr(error, "code", None))
