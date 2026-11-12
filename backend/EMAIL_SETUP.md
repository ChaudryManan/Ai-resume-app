# Gmail SMTP setup for AI job offers

The offer feature uses Gmail SMTP from the FastAPI backend. The Flutter app never receives SMTP credentials.

## 1. Create a Gmail App Password

1. Sign in to the Gmail account that should send recruiter offers.
2. Open Google Account Security: https://myaccount.google.com/security
3. Enable 2-Step Verification.
4. Open App Passwords: https://myaccount.google.com/apppasswords
5. Create an app password (for example, name it `HireFlow Backend`).
6. Copy the 16-character app password. Do not use your normal Gmail password.

Google may not show App Passwords for some account types or accounts managed by an organization.

## 2. Add these values to `backend/.env`

Keep the actual values private. Do not commit the real `.env` file.

```env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_EMAIL=your-sending-account@gmail.com
SMTP_PASSWORD=your-16-character-app-password
```

Paste the App Password without spaces. The backend connects using STARTTLS on port 587.

## 3. Install and run the backend

From the backend folder, install requirements and start FastAPI as usual:

```powershell
pip install -r requirements.txt
uvicorn app.main:app --reload
```

## 4. Offer workflow

1. Admin opens a job's Candidates screen and chooses **Generate job offer**.
2. Admin enters salary and optional benefits, working hours, joining date, and terms.
3. Gemini creates a draft and stores it in Firestore `job_offers` with status `pending_review`.
4. Admin reviews the draft and explicitly chooses **Approve & send email**.
5. FastAPI sends the email through Gmail SMTP and records `sent` or `send_failed` status.

Only authenticated admins can call the offer endpoints. Candidate email is read from the screened Firestore candidate profile; it is not accepted from the Flutter request.

## Important

- Never put SMTP credentials in Flutter, source code, GitHub, or logs.
- Use a dedicated sending Gmail account where possible.
- Gmail has sending and abuse-prevention limits; this SMTP approach is intended for development and modest volumes. For higher-volume production email, use a transactional email provider.
- Verify the candidate's email address and the offer wording before approval. The system does not send anything when the AI draft is generated.
