"""
agents/coach_agent.py — Shadow Coach Agent
The "Conversationalist": warm, engaging, human-sounding coaching messages.

Responsibilities:
1. During verify-step polling: receives a VisionVerdict + step context and
   generates the coaching_message field in CoachResponse (warm tone, 1 sentence).
2. During /coach endpoint: full conversational back-and-forth with the learner,
   maintaining history, with optional frame context.

Max tokens: 500 for both modes.
"""

from __future__ import annotations
import asyncio
import base64
import os
from typing import List, Optional

import anthropic

from models import ConversationMessage, Lesson, Step, VisionVerdict

# ---------------------------------------------------------------------------
# Client (single shared instance)
# ---------------------------------------------------------------------------

_client = anthropic.AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
MODEL = "claude-sonnet-4-6"
MAX_TOKENS = 500

# ---------------------------------------------------------------------------
# System prompts
# ---------------------------------------------------------------------------

# Used during the 2-second polling loop (verify-step coaching message)
COACHING_SYSTEM = """\
You are Shadow, an expert coach watching a learner through AR smart glasses.
You know whether they just completed the current step or not.

Your job: write ONE short, warm, spoken coaching message (1–2 sentences max).

Rules:
- If step_completed=true: briefly celebrate and naturally introduce the next step.
- If step_completed=false: give ONE specific, actionable correction. Not a lecture.
- Use second-person ("you", "your"). Speak like a patient mentor, not a robot.
- Never repeat the full step instruction verbatim.
- Keep it short — this will be spoken aloud over smart glasses audio.
- Do NOT wrap in quotes or JSON. Just the plain coaching message text.
"""

# Used during full conversational turns (/coach endpoint)
CONVERSATION_SYSTEM = """\
You are Shadow, an expert coach helping a learner through a hands-on skill.
You can see their first-person view through AR smart glasses if a frame is provided.
You have context about which step they are on in the lesson.

Be warm, specific, and encouraging. Answer questions concisely and practically.
If you see something in their camera frame that is relevant, mention it specifically.
Keep responses to 2–3 sentences unless the learner explicitly asks for more detail.
Speak naturally — your response will often be read aloud.
"""


# ---------------------------------------------------------------------------
# Public async functions
# ---------------------------------------------------------------------------

async def generate_message(
    step: Step,
    lesson: Lesson,
    verdict: VisionVerdict,
    recent_history: Optional[List[ConversationMessage]] = None,
) -> str:
    """
    Generate a short coaching message for the verify-step polling loop.

    Called in parallel with the Vision Agent via asyncio.gather().
    Receives the VisionVerdict so it knows what the vision agent decided.

    Args:
        step:           The current step being verified
        lesson:         The full lesson (for context about what's next)
        verdict:        The VisionVerdict from the Vision Agent
        recent_history: Optional last 3-4 conversation messages for context

    Returns:
        A short coaching message string (1-2 sentences, spoken aloud)
    """
    # Build context string
    next_step = _get_next_step(step, lesson)
    status_context = (
        f"Step {step.order + 1} COMPLETED ✓ (confidence: {verdict.confidence:.0%}). "
        f"Next step: {next_step.instruction if next_step else 'This was the final step!'}"
        if verdict.step_completed
        else (
            f"Step {step.order + 1} NOT YET COMPLETE (confidence: {verdict.confidence:.0%}). "
            f"Issue: {verdict.error_detail or 'Could not determine specific issue.'}"
        )
    )

    # Optionally include recent conversation context
    history_context = ""
    if recent_history:
        history_context = "\n\nRecent conversation context:\n" + "\n".join(
            f"{m.role.upper()}: {m.content}" for m in recent_history[-4:]
        )

    user_message = (
        f"Lesson: {lesson.title}\n"
        f"Current Step: {step.instruction}\n"
        f"Success Criteria: {step.success_criteria}\n"
        f"Status: {status_context}"
        f"{history_context}\n\n"
        f"Write a short coaching message for the learner now."
    )

    response = await _client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=COACHING_SYSTEM,
        messages=[{"role": "user", "content": user_message}],
    )

    return response.content[0].text.strip()


async def converse(
    step: Step,
    lesson: Lesson,
    conversation_history: List[ConversationMessage],
    user_message: str,
    frame_b64: Optional[str] = None,
) -> tuple[str, List[ConversationMessage]]:
    """
    Handle a full conversational turn with the learner.
    Used by the /coach endpoint.

    Args:
        step:                 Current step the learner is on
        lesson:               Full lesson
        conversation_history: Full conversation so far
        user_message:         What the learner just said/asked
        frame_b64:            Optional base64 JPEG frame for visual context

    Returns:
        Tuple of (reply_text, updated_conversation_history)
    """
    # Build system message with lesson context
    system_with_context = (
        f"{CONVERSATION_SYSTEM}\n\n"
        f"Current Lesson: {lesson.title}\n"
        f"Description: {lesson.description}\n"
        f"Current Step ({step.order + 1} of {len(lesson.steps)}): {step.instruction}\n"
        f"Success Criteria: {step.success_criteria}"
    )

    # Build the message content (with optional frame)
    if frame_b64:
        user_content: list = [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": frame_b64,
                },
            },
            {"type": "text", "text": user_message},
        ]
    else:
        user_content = user_message  # type: ignore[assignment]

    # Append new user message to history
    new_user_msg = ConversationMessage(role="user", content=user_message)
    updated_history = list(conversation_history) + [new_user_msg]

    # Convert history to Anthropic message format
    anthropic_messages = _history_to_anthropic(conversation_history)
    anthropic_messages.append({"role": "user", "content": user_content})

    response = await _client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        system=system_with_context,
        messages=anthropic_messages,
    )

    reply_text = response.content[0].text.strip()

    # Append assistant reply to history
    updated_history.append(ConversationMessage(role="assistant", content=reply_text))

    return reply_text, updated_history


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_next_step(current_step: Step, lesson: Lesson) -> Optional[Step]:
    """Return the step after the current one, or None if last step."""
    try:
        return next(
            s for s in lesson.steps if s.order == current_step.order + 1
        )
    except StopIteration:
        return None


def _history_to_anthropic(history: List[ConversationMessage]) -> list:
    """Convert our ConversationMessage list to Anthropic API message format."""
    return [{"role": m.role, "content": m.content} for m in history]
