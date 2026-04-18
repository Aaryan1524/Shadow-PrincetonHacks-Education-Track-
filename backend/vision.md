## Project: Shadow — AI Coaching App (PrincetonHacks)

### What Shadow Does
Shadow is an AR-powered learning coach that streams first-person video from Meta
Ray-Ban smart glasses to an iPhone, then uses Claude Vision AI to coach the learner
in real time. It replaces passive video tutorials with an active coaching loop that
watches what the learner actually does and responds accordingly.

---

### Architecture Overview
- Hardware: Meta Ray-Ban glasses → streams live camera feed via Bluetooth to iPhone
- iOS App: Swift/SwiftUI, uses Meta Wearables DAT SDK (MetaWearablesDAT 0.6.0)
  to connect to glasses and receive VideoFrame objects from the live stream
- Backend: FastAPI (Python) — YOU ARE BUILDING THIS
- AI: Anthropic Claude claude-sonnet-4-6 with vision (claude-sonnet-4-6)
- Storage: JSON files on server (no database needed for hackathon)

---

### Repo Structure
Shadow-PrincetonHacks-Education-Track-/
├── Shadow/                    ← Xcode iOS project (do not touch)
│   ├── Shadow/                ← Swift source files
│   │   ├── ViewModels/
│   │   │   ├── DeviceSessionManager.swift
│   │   │   ├── StreamSessionViewModel.swift
│   │   │   └── WearablesViewModel.swift
│   │   └── Views/
│   │       ├── HomeScreenView.swift
│   │       ├── MainAppView.swift
│   │       ├── StreamView.swift
│   │       └── PhotoPreviewView.swift
│   └── meta-wearables-dat-ios/  ← Meta DAT SDK submodule
├── backend/                   ← YOU ARE BUILDING THIS
│   ├── main.py
│   ├── requirements.txt
│   ├── .env                   ← secrets (gitignored)
│   └── lessons/               ← JSON lesson storage
└── .gitignore

---

### Core Data Models
These models must be shared between iOS and backend. iOS will serialize/deserialize
these as JSON over HTTP.

#### Lesson
{
  "id": "uuid-string",
  "title": "string",
  "description": "string",
  "created_at": "ISO8601 timestamp",
  "steps": [Step]
}

#### Step
{
  "id": "uuid-string",
  "order": 0,
  "instruction": "What the learner should do (human-readable)",
  "success_criteria": "What it looks like visually when this step is done correctly",
  "reference_image_b64": "base64 JPEG string | null"
}

#### CoachResponse (backend → iOS)
{
  "step_completed": true | false,
  "confidence": 0.0–1.0,
  "coaching_message": "Spoken coaching instruction for the learner",
  "error_detail": "What specifically is wrong (if not completed)",
  "next_step_hint": "Optional preview of what comes next"
}

#### ConversationMessage
{
  "role": "user" | "assistant",
  "content": "string"
}

---

### API Endpoints — Build These Exactly

#### POST /lessons
Create a new lesson (expert flow).
Request body (JSON):
{
  "title": "string",
  "description": "string",
  "steps": [Step]  ← steps without id/reference images yet
}
Response: Lesson (with generated id and created_at)

#### GET /lessons
List all lessons.
Response: [Lesson]

#### GET /lessons/{lesson_id}
Get a single lesson by ID.
Response: Lesson

#### POST /lessons/generate-steps
Expert uploads a video/series of frames, Claude auto-segments into steps.
Request: multipart/form-data
  - frames: list of JPEG files (keyframes extracted from expert recording)
  - task_description: string (what task is being taught)
Response:
{
  "suggested_steps": [Step]  ← expert reviews and edits these
}
Claude prompt for this endpoint: Send all frames + task_description and ask Claude
to segment the task into discrete verifiable steps. For each step return: instruction,
success_criteria (visual description of done state).

#### POST /sessions/{lesson_id}/verify-step
Core coaching loop. iOS calls this every ~2 seconds during learner session.
Request: multipart/form-data
  - frame: JPEG file (current frame from glasses camera)
  - step_index: int (which step we're verifying, 0-indexed)
  - lesson_id: string
Response: CoachResponse

Claude prompt for this endpoint:
  System: "You are a real-time coaching assistant. You have a lesson plan with
  verifiable steps. Analyze the learner's current first-person camera frame and
  determine if they have completed the current step."
  User: [reference image if available] + [live frame] + step instruction +
  success_criteria
  Ask Claude to respond with JSON matching CoachResponse schema.

#### POST /sessions/{lesson_id}/coach
Conversational coaching turn. Called when learner asks a question or needs help.
Request (JSON):
{
  "frame_b64": "base64 JPEG | null",
  "step_index": 0,
  "lesson_id": "string",
  "conversation_history": [ConversationMessage],
  "user_message": "string"
}
Response (JSON):
{
  "reply": "string",
  "updated_history": [ConversationMessage]
}

---

### Tech Stack
- Python 3.11+
- FastAPI + uvicorn
- anthropic (Python SDK) — pip install anthropic
- python-multipart (for file uploads)
- python-dotenv (for .env loading)
- No database — store lessons as JSON files in lessons/ directory

requirements.txt must include:
fastapi
uvicorn[standard]
anthropic
python-multipart
python-dotenv

---

### Environment Variables (.env)
ANTHROPIC_API_KEY=your_key_here
LESSONS_DIR=./lessons

---

### Claude API Usage Notes
- Model: claude-claude-sonnet-4-6 (claude-sonnet-4-6)
- For vision calls: pass images as base64 with media_type "image/jpeg"
- For /verify-step: use structured JSON output — tell Claude to respond ONLY with
  valid JSON matching CoachResponse schema, no extra text
- For /generate-steps: tell Claude to respond ONLY with JSON array of Step objects
- Keep verify-step prompt short and fast — this runs every 2 seconds
- Max tokens for verify-step: 300 (keep latency low)
- Max tokens for coach: 500
- Max tokens for generate-steps: 1000

---

### CORS Configuration
iOS app will hit this server over local WiFi during development.
Enable CORS for all origins during hackathon:
from fastapi.middleware.cors import CORSMiddleware
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"],
allow_headers=["*"])

---

### Local Dev Setup
- Run with: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
- iOS app hits: http://<YOUR_MAC_LOCAL_IP>:8000
- Mac local IP: System Settings → Wi-Fi → Details → IP Address
- Both iPhone and Mac must be on the same Wi-Fi network

---

### iOS ↔ Backend Contract (how iOS will call you)
- Frames come as JPEG data, ~640x480 or smaller (compressed before sending)
- The iOS app sends multipart/form-data for endpoints with images
- The iOS app sends JSON body for the /coach endpoint
- All responses must be valid JSON — no plain text responses
- Latency target for /verify-step: under 3 seconds end-to-end
- The iOS app polls /verify-step every 2 seconds while a session is active

---

### What NOT to Build
- No auth/login — not needed for hackathon
- No user accounts
- No database (use JSON files)
- No video storage — iOS sends individual frames, not video files
- No WebSockets — simple HTTP polling is fine

---

### Deployment (after local works)
Deploy to Railway.app:
- Add Procfile: web: uvicorn main:app --host 0.0.0.0 --port $PORT
- Set ANTHROPIC_API_KEY as environment variable in Railway dashboard
- Update iOS base URL from local IP to Railway URL