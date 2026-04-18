"""
agents/vision_agent.py — Shadow Vision Agent
The "Heavy Lifter": cold, fast, analytical frame analysis.

Responsibilities:
- Receives a camera frame (bytes) + current Step + full Lesson
- Calls Claude claude-sonnet-4-6 with vision (+ reference image if available)
- Returns a VisionVerdict with step_completed, confidence, error_detail
- Optimized for SPEED: max 300 tokens, terse JSON-only output
"""

from __future__ import annotations
import asyncio
import base64
import json
import os
import re
from typing import Optional

import anthropic

from models import Lesson, Step, VisionVerdict

# ---------------------------------------------------------------------------
# Client (single shared instance)
# ---------------------------------------------------------------------------

_client = anthropic.AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
MODEL = "claude-sonnet-4-6"
MAX_TOKENS = 300

# ---------------------------------------------------------------------------
# System prompt — terse, analytical, structured output only
# ---------------------------------------------------------------------------

SYSTEM_PROMPT = """\
You are a computer vision analysis system for a real-time step-by-step task coaching app.
You receive a first-person camera frame from smart AR glasses worn by a learner.

Your ONLY job: determine with precision whether the learner has visually completed the CURRENT step.

Rules:
- Respond ONLY with a single valid JSON object. No preamble, no explanation outside the JSON.
- Be conservative: only mark step_completed=true when you are clearly confident.
- error_detail must be 1 short sentence about what is specifically wrong (if not completed).
- next_step_hint is optional — only include if you can clearly anticipate the next logical action.

JSON schema (respond in this exact format):
{
  "step_completed": true | false,
  "confidence": 0.0 to 1.0,
  "error_detail": "string or null",
  "next_step_hint": "string or null"
}
"""


# ---------------------------------------------------------------------------
# Public async function
# ---------------------------------------------------------------------------

async def verify(
    frame_bytes: bytes,
    step: Step,
    lesson: Lesson,
) -> VisionVerdict:
    """
    Analyze a single camera frame and determine if the current step is complete.

    Args:
        frame_bytes: Raw JPEG bytes from the glasses camera
        step:        The Step currently being verified
        lesson:      The full Lesson (for context)

    Returns:
        VisionVerdict with step_completed, confidence, error_detail, next_step_hint
    """
    frame_b64 = base64.standard_b64encode(frame_bytes).decode("utf-8")

    # Build the content list — reference image first (if available), then live frame
    content: list = []

    if step.reference_image_b64:
        content.append({
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": "image/jpeg",
                "data": step.reference_image_b64,
            },
        })
        content.append({
            "type": "text",
            "text": "REFERENCE IMAGE (what the completed step looks like):",
        })

    content.append({
        "type": "image",
        "source": {
            "type": "base64",
            "media_type": "image/jpeg",
            "data": frame_b64,
        },
    })
    content.append({
        "type": "text",
        "text": (
            f"LIVE CAMERA FRAME (what the learner is doing right now):\n\n"
            f"Lesson: {lesson.title}\n"
            f"Current Step {step.order + 1}: {step.instruction}\n"
            f"Success Criteria: {step.success_criteria}\n\n"
            f"Is this step complete? Respond with JSON only."
        ),
    })

    response = await _client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": content}],
    )

    raw = response.content[0].text.strip()
    return _parse_verdict(raw)


# ---------------------------------------------------------------------------
# Step auto-generation (used by /lessons/generate-steps)
# ---------------------------------------------------------------------------

GENERATE_STEPS_SYSTEM = """\
You are an expert instructional designer analyzing a video sequence.
Given a series of keyframes and a task description, break the task into discrete, verifiable steps.
Each step must have a clear visual success criteria — something that can be confirmed by looking at a camera frame.
Respond ONLY with a valid JSON array. No preamble.

JSON schema for each step:
{
  "order": 0,
  "instruction": "What the learner does (imperative, concise)",
  "success_criteria": "What it visually looks like when this step is done",
  "reference_image_b64": null
}
"""


async def generate_steps(
    frame_bytes_list: list[bytes],
    task_description: str,
) -> list[dict]:
    """
    Given a list of keyframes and a task description, ask Claude to
    segment the task into verifiable steps.
    """
    content: list = []
    for i, frame_bytes in enumerate(frame_bytes_list):
        b64 = base64.standard_b64encode(frame_bytes).decode("utf-8")
        content.append({
            "type": "text",
            "text": f"Frame {i + 1}:",
        })
        content.append({
            "type": "image",
            "source": {"type": "base64", "media_type": "image/jpeg", "data": b64},
        })

    content.append({
        "type": "text",
        "text": (
            f"Task Description: {task_description}\n\n"
            "Segment this task into discrete verifiable steps. "
            "Respond with a JSON array only."
        ),
    })

    response = await _client.messages.create(
        model=MODEL,
        max_tokens=1000,
        system=GENERATE_STEPS_SYSTEM,
        messages=[{"role": "user", "content": content}],
    )

    raw = response.content[0].text.strip()
    return _parse_json_array(raw)


# ---------------------------------------------------------------------------
# Parsing helpers
# ---------------------------------------------------------------------------

def _parse_verdict(raw: str) -> VisionVerdict:
    """Parse Claude's JSON response into a VisionVerdict, with safe fallbacks."""
    try:
        # Strip markdown code fences if Claude wraps the JSON
        clean = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE).strip()
        data = json.loads(clean)
        return VisionVerdict(
            step_completed=bool(data.get("step_completed", False)),
            confidence=float(data.get("confidence", 0.0)),
            error_detail=data.get("error_detail"),
            next_step_hint=data.get("next_step_hint"),
        )
    except Exception:
        # Safe fallback if Claude returns unexpected output
        return VisionVerdict(
            step_completed=False,
            confidence=0.0,
            error_detail="Could not analyze frame — please try again.",
        )


def _parse_json_array(raw: str) -> list:
    """Parse Claude's JSON array response, with safe fallback."""
    try:
        clean = re.sub(r"^```(?:json)?\s*|\s*```$", "", raw, flags=re.MULTILINE).strip()
        return json.loads(clean)
    except Exception:
        return []
