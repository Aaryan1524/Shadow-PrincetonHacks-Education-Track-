import asyncio
import base64
import datetime
import glob
import json
import os
import re
import uuid
from typing import List, Literal, Optional

from dotenv import load_dotenv

# Load .env FIRST — before any module that reads env vars at import time
load_dotenv()

from fastapi import FastAPI, Form, HTTPException, UploadFile, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import anthropic

from agents.conversation_coach import coach_conversation
from agents.voice_coach import build_wav_from_pcm, transcribe_and_coach

# ─────────────────────────────────────────────────────────────────────────────
# Configuration
# ─────────────────────────────────────────────────────────────────────────────

ANTHROPIC_API_KEY = os.environ.get("ANTHROPIC_API_KEY", "")
LESSONS_DIR = os.environ.get("LESSONS_DIR", "./lessons")
MODEL = "claude-sonnet-4-6"

# Create lessons directory if it does not exist.
os.makedirs(LESSONS_DIR, exist_ok=True)

# Module-level Anthropic client.
client = anthropic.Anthropic()

# ─────────────────────────────────────────────────────────────────────────────
# FastAPI App + CORS
# ─────────────────────────────────────────────────────────────────────────────

app = FastAPI(title="Shadow Coaching Backend", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─────────────────────────────────────────────────────────────────────────────
# Pydantic Models
# ─────────────────────────────────────────────────────────────────────────────


class Step(BaseModel):
    id: str
    order: int
    instruction: str
    success_criteria: str
    reference_image_b64: Optional[str] = None


class Lesson(BaseModel):
    id: str
    title: str
    description: str
    created_at: str
    steps: List[Step]


class CoachResponse(BaseModel):
    step_completed: bool
    confidence: float
    coaching_message: str
    error_detail: str
    next_step_hint: str


class ConversationMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str


class StepCreateRequest(BaseModel):
    instruction: str
    success_criteria: str


class LessonCreateRequest(BaseModel):
    title: str
    description: str
    steps: List[StepCreateRequest]


class CoachRequest(BaseModel):
    frame_b64: Optional[str] = None
    step_index: int
    lesson_id: str
    conversation_history: List[ConversationMessage]
    user_message: str


class CoachConversationResponse(BaseModel):
    reply: str
    updated_history: List[ConversationMessage]


# ─────────────────────────────────────────────────────────────────────────────
# Storage Layer
# ─────────────────────────────────────────────────────────────────────────────


def _lesson_path(lesson_id: str) -> str:
    """Return the full file path for a lesson JSON file."""
    return os.path.join(LESSONS_DIR, f"{lesson_id}.json")


def save_lesson(lesson: Lesson) -> None:
    """Serialize a Lesson to disk as JSON."""
    path = _lesson_path(lesson.id)
    with open(path, "w", encoding="utf-8") as f:
        f.write(lesson.model_dump_json())


def load_lesson(lesson_id: str) -> Lesson:
    """
    Load a Lesson from disk by its ID.
    Raises HTTPException 404 if the file does not exist.
    """
    path = _lesson_path(lesson_id)
    if not os.path.isfile(path):
        raise HTTPException(
            status_code=404,
            detail=f"Lesson '{lesson_id}' not found.",
        )
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return Lesson(**data)


def list_all_lessons() -> List[Lesson]:
    """Read and return all lessons from the lessons/ directory."""
    pattern = os.path.join(LESSONS_DIR, "*.json")
    lessons = []
    for filepath in glob.glob(pattern):
        with open(filepath, "r", encoding="utf-8") as f:
            data = json.load(f)
        lessons.append(Lesson(**data))
    return lessons


# ─────────────────────────────────────────────────────────────────────────────
# API Endpoints
# ─────────────────────────────────────────────────────────────────────────────


@app.post("/lessons", response_model=Lesson)
async def create_lesson(request: LessonCreateRequest) -> Lesson:
    """Create a new lesson from a JSON body and save to disk."""
    lesson_id = str(uuid.uuid4())
    created_at = (
        datetime.datetime.now(datetime.timezone.utc)
        .strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3]
        + "Z"
    )

    steps = [
        Step(
            id=str(uuid.uuid4()),
            order=idx,
            instruction=step.instruction,
            success_criteria=step.success_criteria,
            reference_image_b64=None,
        )
        for idx, step in enumerate(request.steps)
    ]

    lesson = Lesson(
        id=lesson_id,
        title=request.title,
        description=request.description,
        created_at=created_at,
        steps=steps,
    )

    save_lesson(lesson)
    return lesson


@app.get("/lessons", response_model=List[Lesson])
async def get_lessons() -> List[Lesson]:
    """Return all saved lessons."""
    return list_all_lessons()


@app.post("/lessons/generate-steps")
async def generate_steps(
    frames: List[UploadFile],
    task_description: str = Form(...),
) -> dict:
    """
    Accept keyframes from an expert recording and ask Claude to segment
    the task into discrete verifiable steps.

    Request: multipart/form-data
      - frames: one or more JPEG files (field name 'frames', repeated)
      - task_description: string describing the task

    Response: {"suggested_steps": [Step]}
    """
    # Read and base64-encode each uploaded frame
    content = []
    for idx, frame_file in enumerate(frames):
        frame_bytes = await frame_file.read()
        frame_b64 = base64.b64encode(frame_bytes).decode("utf-8")
        content.append({"type": "text", "text": f"Frame {idx + 1}:"})
        content.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": frame_b64,
                },
            }
        )

    # Append the instruction prompt
    prompt = (
        f"Task description: {task_description}\n\n"
        "The frames above show an expert performing this task in sequence. "
        "Analyze the frames and break the task into discrete, verifiable steps.\n\n"
        "Respond ONLY with a valid JSON array. No explanation, no markdown, no "
        "extra text before or after. Each element must have exactly these two fields:\n"
        "[\n"
        '  {\n'
        '    "instruction": "Clear, actionable description of what the learner should do",\n'
        '    "success_criteria": "Visual description of what it looks like when this step is done correctly"\n'
        "  }\n"
        "]"
    )
    content.append({"type": "text", "text": prompt})

    response = client.messages.create(
        model=MODEL,
        max_tokens=1000,
        system=(
            "You are an expert task decomposition assistant. You analyze images "
            "of someone performing a task and break it into discrete, verifiable steps."
        ),
        messages=[{"role": "user", "content": content}],
    )

    raw_text = response.content[0].text.strip()

    # Parse Claude's response as a JSON array.
    try:
        steps_data = json.loads(raw_text)
    except json.JSONDecodeError:
        match = re.search(r"\[.*\]", raw_text, re.DOTALL)
        if not match:
            raise HTTPException(
                status_code=500,
                detail=(
                    "Claude did not return a valid JSON array. "
                    f"Raw response: {raw_text[:200]}"
                ),
            )
        try:
            steps_data = json.loads(match.group())
        except json.JSONDecodeError as exc:
            raise HTTPException(
                status_code=500,
                detail=f"Failed to parse extracted JSON: {exc}",
            )

    # Convert raw dicts to Step objects with generated IDs
    suggested_steps = [
        Step(
            id=str(uuid.uuid4()),
            order=idx,
            instruction=item["instruction"],
            success_criteria=item["success_criteria"],
            reference_image_b64=None,
        )
        for idx, item in enumerate(steps_data)
    ]

    return {"suggested_steps": [s.model_dump() for s in suggested_steps]}


@app.get("/lessons/{lesson_id}", response_model=Lesson)
async def get_lesson(lesson_id: str) -> Lesson:
    """Return a single lesson by ID, or 404 if not found."""
    return load_lesson(lesson_id)


@app.post("/sessions/{lesson_id}/verify-step", response_model=CoachResponse)
async def verify_step(
    lesson_id: str,
    frame: UploadFile,
    step_index: int = Form(...),
) -> CoachResponse:
    """
    Core real-time coaching loop. iOS calls this every ~2 seconds.

    Request: multipart/form-data
      - frame: JPEG file (single frame from glasses camera)
      - step_index: int (0-indexed step being verified)

    Response: CoachResponse JSON
    """
    # Load the lesson (raises 404 if not found)
    lesson = load_lesson(lesson_id)

    # Validate step_index range
    if step_index < 0 or step_index >= len(lesson.steps):
        raise HTTPException(
            status_code=400,
            detail=(
                f"step_index {step_index} is out of range. "
                f"Lesson '{lesson_id}' has {len(lesson.steps)} steps (0-indexed)."
            ),
        )

    step = lesson.steps[step_index]

    # Read and encode the live frame
    frame_bytes = await frame.read()
    live_frame_b64 = base64.b64encode(frame_bytes).decode("utf-8")

    # Build content blocks: [reference_image?] + [live_frame] + [prompt_text]
    content = []

    if step.reference_image_b64:
        content.append(
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": step.reference_image_b64,
                },
            }
        )
        content.append(
            {"type": "text", "text": "Reference image showing the completed step:"}
        )

    content.append(
        {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/jpeg",
                "data": live_frame_b64,
            },
        }
    )

    prompt_text = (
        "Current learner camera frame (above).\n\n"
        f"Step instruction: {step.instruction}\n"
        f"Success criteria: {step.success_criteria}\n\n"
        "Respond ONLY with valid JSON matching this exact schema — no markdown, "
        "no explanation, no extra text:\n"
        "{\n"
        '  "step_completed": <true|false>,\n'
        '  "confidence": <float between 0.0 and 1.0>,\n'
        '  "coaching_message": "<encouraging message for the learner>",\n'
        '  "error_detail": "<what is wrong if not completed, empty string if completed>",\n'
        '  "next_step_hint": "<brief preview of what comes next, empty string if step not yet completed>"\n'
        "}"
    )
    content.append({"type": "text", "text": prompt_text})

    # Call Claude
    try:
        response = client.messages.create(
            model=MODEL,
            max_tokens=300,
            system=(
                "You are a real-time coaching assistant. Analyze the learner's "
                "current camera frame and determine if they have completed the "
                "current step. Respond ONLY with valid JSON."
            ),
            messages=[{"role": "user", "content": content}],
        )
        raw_text = response.content[0].text.strip()
    except Exception as e:
        # Claude API failure — return safe fallback rather than crashing
        print(f"❌ Claude API error in verify-step: {type(e).__name__}: {e}")
        return CoachResponse(
            step_completed=False,
            confidence=0.0,
            coaching_message="Unable to analyze frame. Please try again.",
            error_detail=f"Claude API error: {type(e).__name__}",
            next_step_hint="",
        )

    # Parse JSON response with fallback
    try:
        parsed = json.loads(raw_text)
    except json.JSONDecodeError:
        # Claude added preamble — try to extract the JSON object
        match = re.search(r"\{.*\}", raw_text, re.DOTALL)
        if match:
            try:
                parsed = json.loads(match.group())
            except json.JSONDecodeError:
                parsed = None
        else:
            parsed = None

    if parsed is None:
        return CoachResponse(
            step_completed=False,
            confidence=0.0,
            coaching_message="Unable to analyze frame. Please try again.",
            error_detail="Parse error: Claude response was not valid JSON",
            next_step_hint="",
        )

    return CoachResponse(
        step_completed=bool(parsed.get("step_completed", False)),
        confidence=float(parsed.get("confidence", 0.0)),
        coaching_message=str(parsed.get("coaching_message", "")),
        error_detail=str(parsed.get("error_detail", "")),
        next_step_hint=str(parsed.get("next_step_hint", "")),
    )


@app.post("/sessions/{lesson_id}/coach", response_model=CoachConversationResponse)
async def coach(lesson_id: str, request: CoachRequest) -> CoachConversationResponse:
    """
    Conversational coaching turn. Called when the learner asks a question.

    Request: JSON body (CoachRequest)
    Response: CoachConversationResponse
    """
    # Load lesson (raises 404 if not found)
    lesson = load_lesson(lesson_id)

    # Validate step_index
    if request.step_index < 0 or request.step_index >= len(lesson.steps):
        raise HTTPException(
            status_code=400,
            detail=(
                f"step_index {request.step_index} is out of range. "
                f"Lesson has {len(lesson.steps)} steps."
            ),
        )

    step = lesson.steps[request.step_index]

    # Convert Pydantic ConversationMessage objects to plain dicts for coach_conversation
    history_dicts = [
        {"role": msg.role, "content": msg.content}
        for msg in request.conversation_history
    ]

    # Delegate to the conversation coach agent
    result = coach_conversation(
        user_message=request.user_message,
        conversation_history=history_dicts,
        frame_b64=request.frame_b64,
        step_instruction=step.instruction,
        lesson_title=lesson.title,
    )

    # Convert updated_history dicts back to ConversationMessage Pydantic models
    updated_history = [
        ConversationMessage(role=m["role"], content=m["content"])
        for m in result["updated_history"]
    ]

    return CoachConversationResponse(
        reply=result["reply"],
        updated_history=updated_history,
    )


@app.websocket("/ws/sessions/{lesson_id}")
async def voice_session(websocket: WebSocket, lesson_id: str) -> None:
    """
    Real-time voice coaching session.

    Protocol (client → server):
      {"type": "audio_chunk",    "data": "<base64 PCM bytes>"}
      {"type": "end_of_speech"}
      {"type": "context_update", "step_index": <int>, "coach_response": {CoachResponse fields}}
      {"type": "ping"}

    Protocol (server → client):
      {"type": "ready"}
      {"type": "processing"}
      {"type": "audio_response", "data": "<base64 MP3>|null", "reply": "<text>"}
      {"type": "error",          "message": "<text>"}
      {"type": "pong"}
    """
    await websocket.accept()

    # ── Per-connection mutable state ──────────────────────────────────────────
    audio_buffer: bytearray = bytearray()
    conversation_history: list[dict] = []   # {"role": "user"|"model", "content": str}
    latest_coach_response: dict | None = None  # injected by context_update messages

    # ── Load lesson once upfront ──────────────────────────────────────────────
    try:
        lesson = load_lesson(lesson_id)
    except HTTPException as e:
        print(f"❌ Lesson not found: {lesson_id}")
        try:
            await websocket.send_json({
                "type": "error",
                "message": f"Lesson '{lesson_id}' not found.",
            })
        except Exception as send_err:
            print(f"❌ Failed to send error to client: {send_err}")
        await websocket.close(code=1008)   # 1008 = Policy Violation
        return

    try:
        await websocket.send_json({"type": "ready"})
        print(f"✓ WebSocket ready for lesson {lesson_id}")
    except Exception as ready_err:
        print(f"❌ Failed to send ready message: {ready_err}")
        return

    # ── Main message loop ─────────────────────────────────────────────────────
    try:
        while True:
            try:
                msg = await websocket.receive_json()
                msg_type = msg.get("type", "")
                print(f"📨 Received message type: {msg_type}")
            except Exception as recv_err:
                print(f"❌ Error receiving message: {recv_err}")
                break

            # ── audio_chunk: accumulate PCM data ──────────────────────────
            if msg_type == "audio_chunk":
                raw = msg.get("data", "")
                if raw:
                    try:
                        chunk = base64.b64decode(raw)
                        audio_buffer.extend(chunk)
                    except Exception:
                        pass  # malformed chunk — ignore silently

            # ── end_of_speech: process accumulated audio ──────────────────
            elif msg_type == "end_of_speech":
                if not audio_buffer:
                    continue  # nothing to process

                await websocket.send_json({"type": "processing"})

                # Determine which lesson step we are on
                step_index: int = 0
                if latest_coach_response is not None:
                    step_index = int(latest_coach_response.get("step_index", 0))
                step_index = min(step_index, len(lesson.steps) - 1)
                step = lesson.steps[step_index]

                # Snapshot and clear buffer atomically within the event loop
                pcm_snapshot = bytes(audio_buffer)
                audio_buffer.clear()

                # Offload the blocking Gemini + gTTS call to a thread
                try:
                    result = await asyncio.to_thread(
                        transcribe_and_coach,
                        wav_bytes=build_wav_from_pcm(pcm_snapshot),
                        lesson_title=lesson.title,
                        step_instruction=step.instruction,
                        success_criteria=step.success_criteria,
                        step_index=step_index,
                        total_steps=len(lesson.steps),
                        conversation_history=conversation_history,
                        coach_response=latest_coach_response,
                    )
                    conversation_history = result["updated_history"]
                    await websocket.send_json({
                        "type": "audio_response",
                        "data": result["audio_b64"],   # None if gTTS failed
                        "reply": result["reply"],
                    })
                except Exception as proc_err:
                    import traceback
                    print(f"❌ Voice processing error: {type(proc_err).__name__}: {proc_err}")
                    traceback.print_exc()
                    try:
                        await websocket.send_json({
                            "type": "error",
                            "message": f"Could not process audio: {str(proc_err)[:100]}",
                        })
                    except Exception as send_err:
                        print(f"❌ Failed to send error message: {send_err}")
                    # Do NOT close — allow next speech turn

            # ── context_update: iOS pushes latest verify-step result ───────
            elif msg_type == "context_update":
                coach_data = msg.get("coach_response")
                if isinstance(coach_data, dict):
                    latest_coach_response = dict(coach_data)
                    latest_coach_response["step_index"] = int(msg.get("step_index", 0))

            # ── ping / keepalive ──────────────────────────────────────────
            elif msg_type == "ping":
                await websocket.send_json({"type": "pong"})

            # ── unknown message types: ignore ─────────────────────────────

    except WebSocketDisconnect:
        pass  # Client disconnected cleanly — no log needed

    except Exception as fatal_err:
        print(f"WebSocket fatal error (lesson={lesson_id}): {fatal_err}")
        try:
            await websocket.send_json({"type": "error", "message": str(fatal_err)})
        except Exception:
            pass  # socket may already be closed
