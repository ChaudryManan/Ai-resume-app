
import firebase_admin
from firebase_admin import credentials, auth

SERVICE_ACCOUNT_PATH = (
    r"C:\Users\Manan\Downloads\ai-resume-650e4-firebase-adminsdk-fbsvc-d290791b2c.json"
)

# Initialize Firebase
cred = credentials.Certificate(SERVICE_ACCOUNT_PATH)
firebase_admin.initialize_app(cred)

print("Connected to Firebase successfully!")

# Get the first page of Firebase users
page = auth.list_users()

count = 0

while page:
    for user in page.users:

        # Preserve existing custom claims
        claims = dict(user.custom_claims or {})

        # Add Supabase authentication claim
        claims["role"] = "authenticated"

        # Update Firebase user
        auth.set_custom_user_claims(user.uid, claims)

        count += 1
        print(f"Updated: {user.email or user.uid}")

    # Get the next page of users
    page = page.get_next_page()

print(f"\nSuccessfully updated {count} Firebase users.")
