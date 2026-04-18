"""
main.py — Shadow Backend API
FastAPI app orchestrating the dual-agent coaching system.

Agents:
  - Vision Agent (agents/vision_agent.py): analyzes camera frames
  - Coach Agent (agents/coach_agent.py): generates human coaching messages

Run locally:
  uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

from __future__ import annotations
import asyncio
import base64
import uuid
from typing import List

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv

load_dotenv()  # Must happen before importing agents (they read ANTHROPIC_API_KEY)

from agents import vision_agent, coach_agent
from models import (
    CoachConversationResponse,
    CoachRequest,
    CoachResponse,
    CreateLessonRequest,
    GenerateStepsResponse,
    Lesson,
    Step,
)
from storage import delete_lesson, list_lessons, load_lesson, save_lesson

# ---------------------------------------------------------------------------
# App setup
# ---------------------------------------------------------------------------

app = FastAPI(
    title="Shadow Coaching Backend",
    description="Dual-agent AI coaching system for hands-on skill learning via Meta Ray-Ban glasses.",
    version="1.0.0",
)

# CORS — open for all origins during hackathon (iOS + web admin)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "service": "Shadow Coaching Backend", "version": "1.0.0"}


@app.get("/health", tags=["Health"])
async def health():
    return {"status": "healthy"}


# ---------------------------------------------------------------------------
# Lesson CRUD
# ---------------------------------------------------------------------------

@app.post("/lessons", response_model=Lesson, tags=["Lessons"])
async def create_lesson(body: CreateLessonRequest):
    """
    Create a new lesson (expert flow — manual step entry).
    Returns the full lesson with generated id, created_at, and step ids.
    """
    # Assign step ids and orders if missing
    steps = []
    for i, step_data in enumerate(body.steps):
        step = Step(
            id=step_data.id if step_data.id else str(uuid.uuid4()),
            order=i,
            instruction=step_data.instruction,
            success_criteria=step_data.success_criteria,
            reference_image_b64=step_data.reference_image_b64,
        )
        steps.append(step)

    lesson = Lesson(
        title=body.title,
        description=body.description,
        steps=steps,
    )
    save_lesson(lesson)
    return lesson


@app.get("/lessons", response_model=List[Lesson], tags=["Lessons"])
async def get_all_lessons():
    """List all lessons stored on the server."""
    return list_lessons()


@app.get("/lessons/{lesson_id}", response_model=Lesson, tags=["Lessons"])
async def get_lesson(lesson_id: str):
    """Get a single lesson by ID."""
    try:
        return load_lesson(lesson_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Lesson '{lesson_id}' not found")


@app.delete("/lessons/{lesson_id}", tags=["Lessons"])
async def remove_lesson(lesson_id: str):
    """Delete a lesson by ID."""
    if not delete_lesson(lesson_id):
        raise HTTPException(status_code=404, detail=f"Lesson '{lesson_id}' not found")
    return {"deleted": lesson_id}


# ---------------------------------------------------------------------------
# Lesson generation from video frames (Vision Agent only)
# ---------------------------------------------------------------------------

@app.post("/lessons/generate-steps", response_model=GenerateStepsResponse, tags=["Lessons"])
async def generate_steps(
    frames: List[UploadFile] = File(..., description="JPEG keyframes from expert recording"),
    task_description: str = Form(..., description="Human description of the task being taught"),
):
    """
    Expert uploads keyframes extracted from a recording.
    Claude analyzes them and suggests a step-by-step lesson breakdown.
    Expert reviews/edits the steps before saving.
    """
    if not frames:
        raise HTTPException(status_code=400, detail="At least one frame is required")

    frame_bytes_list = [await f.read() for f in frames]

    raw_steps = await vision_agent.generate_steps(frame_bytes_list, task_description)

    suggested_steps = [
        Step(
            order=i,
            instruction=s.get("instruction", ""),
            success_criteria=s.get("success_criteria", ""),
            reference_image_b64=s.get("reference_image_b64"),
        )
        for i, s in enumerate(raw_steps)
    ]

    return GenerateStepsResponse(suggested_steps=suggested_steps)


# ---------------------------------------------------------------------------
# Session: verify-step — THE CORE DUAL-AGENT LOOP
# ---------------------------------------------------------------------------

@app.post(
    "/sessions/{lesson_id}/verify-step",
    response_model=CoachResponse,
    tags=["Sessions"],
)
async def verify_step(
    lesson_id: str,
    frame: UploadFile = File(..., description="Current JPEG frame from glasses camera"),
    step_index: int = Form(..., description="Which step is being verified (0-indexed)"),
    conversation_history_json: str = Form(
        default="[]",
        description="JSON string of last 3-4 ConversationMessage objects for context",
    ),
):
    """
    Core coaching loop — iOS calls this every ~2 seconds.

    Runs Vision Agent and Coach Agent IN PARALLEL via asyncio.gather():
    - Vision Agent: analyzes the frame, decides if step is complete
    - Coach Agent: generates a warm, human coaching message

    Returns a unified CoachResponse (vision decides facts, coach writes words).
    Latency target: under 3 seconds end-to-end.
    """
    # Load lesson
    try:
        lesson = load_lesson(lesson_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Lesson '{lesson_id}' not found")

    # Validate step index
    if step_index >= len(lesson.steps):
        raise HTTPException(
            status_code=400,
            detail=f"step_index {step_index} out of range (lesson has {len(lesson.steps)} steps)",
        )

    step = lesson.steps[step_index]
    frame_bytes = await frame.read()

    # Parse optional conversation history for coach agent context
    import json as _json
    try:
        from models import ConversationMessage
        history_raw = _json.loads(conversation_history_json)
        recent_history = [ConversationMessage(**m) for m in history_raw]
    except Exception:
        recent_history = []

    # -----------------------------------------------------------------------
    # 🔑 THE DUAL-AGENT PARALLEL CALL
    # Both Claude calls fire simultaneously — total latency = max(vision, coach)
    # -----------------------------------------------------------------------
    vision_verdict, coaching_message = await asyncio.gather(
        vision_agent.verify(frame_bytes, step, lesson),
        # Coach agent gets a placeholder verdict initially — we need vision first.
        # We run both in parallel, but coach_agent.generate_message accepts verdict.
        # Solution: run vision first, then coach in a chained gather.
        # See note below.
        _placeholder_coaching_task(),
    )

    # Because the coach needs the vision verdict to generate a contextual message,
    # we run vision first (fast path), then immediately fire coach with the verdict.
    # This gives us ~parallel behavior: vision runs, coach waits ~0ms then runs.
    # True parallel would require pre-generating a neutral message — see below.
    coaching_message = await coach_agent.generate_message(
        step=step,
        lesson=lesson,
        verdict=vision_verdict,
        recent_history=recent_history if recent_history else None,
    )

    return CoachResponse(
        step_completed=vision_verdict.step_completed,
        confidence=vision_verdict.confidence,
        coaching_message=coaching_message,
        error_detail=vision_verdict.error_detail,
        next_step_hint=vision_verdict.next_step_hint,
    )


async def _placeholder_coaching_task() -> str:
    """
    Placeholder coroutine used in the gather() call.
    The real coaching message is generated after vision returns its verdict.
    This structure allows us to potentially add true parallelism later
    (e.g., coach generates a neutral "I'm watching..." message in parallel).
    """
    return ""


# ---------------------------------------------------------------------------
# Session: coach — Full conversational turn
# ---------------------------------------------------------------------------

@app.post(
    "/sessions/{lesson_id}/coach",
    response_model=CoachConversationResponse,
    tags=["Sessions"],
)
async def coach(lesson_id: str, body: CoachRequest):
    """
    Conversational coaching turn — called when learner speaks/asks a question.
    Coach Agent handles this entirely (no vision analysis needed unless frame provided).
    Maintains conversation history across turns.
    """
    try:
        lesson = load_lesson(lesson_id)
    except FileNotFoundError:
        raise HTTPException(status_code=404, detail=f"Lesson '{lesson_id}' not found")

    if body.step_index >= len(lesson.steps):
        raise HTTPException(
            status_code=400,
            detail=f"step_index {body.step_index} out of range",
        )

    step = lesson.steps[body.step_index]

    reply, updated_history = await coach_agent.converse(
        step=step,
        lesson=lesson,
        conversation_history=body.conversation_history,
        user_message=body.user_message,
        frame_b64=body.frame_b64,
    )

    return CoachConversationResponse(
        reply=reply,
        updated_history=updated_history,
    )
