"""
models.py — Shadow Backend Data Contracts
All Pydantic models shared across routes and agents.
"""

from __future__ import annotations
from typing import Optional, List
from pydantic import BaseModel, Field
from datetime import datetime
import uuid


# ---------------------------------------------------------------------------
# Lesson data models
# ---------------------------------------------------------------------------

class Step(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    order: int
    instruction: str
    success_criteria: str
    reference_image_b64: Optional[str] = None  # base64 JPEG or null


class Lesson(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    title: str
    description: str
    created_at: str = Field(
        default_factory=lambda: datetime.utcnow().isoformat() + "Z"
    )
    steps: List[Step] = []


# ---------------------------------------------------------------------------
# Request bodies
# ---------------------------------------------------------------------------

class CreateLessonRequest(BaseModel):
    title: str
    description: str
    steps: List[Step] = []


class ConversationMessage(BaseModel):
    role: str   # "user" | "assistant"
    content: str


class CoachRequest(BaseModel):
    frame_b64: Optional[str] = None          # base64 JPEG or null
    step_index: int = 0
    lesson_id: str
    conversation_history: List[ConversationMessage] = []
    user_message: str


# ---------------------------------------------------------------------------
# Response bodies
# ---------------------------------------------------------------------------

class CoachResponse(BaseModel):
    step_completed: bool
    confidence: float                         # 0.0 – 1.0
    coaching_message: str
    error_detail: Optional[str] = None
    next_step_hint: Optional[str] = None


class CoachConversationResponse(BaseModel):
    reply: str
    updated_history: List[ConversationMessage]


class GenerateStepsResponse(BaseModel):
    suggested_steps: List[Step]


# ---------------------------------------------------------------------------
# Internal shared model between agents
# ---------------------------------------------------------------------------

class VisionVerdict(BaseModel):
    """
    Internal model produced by the Vision Agent.
    Passed into the Coach Agent so it can generate a contextual message.
    """
    step_completed: bool
    confidence: float
    error_detail: Optional[str] = None
    next_step_hint: Optional[str] = None
