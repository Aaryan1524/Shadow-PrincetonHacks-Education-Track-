"""
agents/coach_agent.py — Shadow Coach Agent (powered by Gemini 2.0 Flash)
The "Conversationalist": warm, engaging, human-sounding coaching messages.

Uses Google Gemini 2.0 Flash for ultra-low latency — critical for smooth TTS
voice output through the smart glasses audio system.

Responsibilities:
1. During verify-step polling: receives VisionVerdict + step context and generates
   the coaching_message field in CoachResponse (warm tone, 1–2 sentences).
2. During /coach endpoint: full conversational back-and-forth with the learner,
   maintaining history, with optional frame context.

Max output tokens: 200 for coaching messages, 400 for conversations.
"""

from __future__ import annotations
import asyncio
import base64
import os
from typing import List, Optional

from google import genai
from google.genai import types

from models import ConversationMessage, Lesson, Step, VisionVerdict

# ---------------------------------------------------------------------------
# Client (single shared instance)
# ---------------------------------------------------------------------------

_client = genai.Client(api_key=os.getenv("GOOGLE_API_KEY"))
MODEL = "gemini-2.0-flash"

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
- Do NOT wrap in quotes or JSON. Just the plain coaching message text.\
"""

# Used during full conversational turns (/coach endpoint)
CONVERSATION_SYSTEM = """\
You are Shadow, an expert coach helping a learner through a hands-on skill.
You can see their first-person view through AR smart glasses if a frame is provided.
You have context about which step they are on in the lesson.

Be warm, specific, and encouraging. Answer questions concisely and practically.
If you see something in their camera frame that is relevant, mention it specifically.
Keep responses to 2–3 sentences unless the learner explicitly asks for more detail.
Speak naturally — your response will be read aloud.\
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
    Called after Vision Agent returns its verdict.
    Powered by Gemini 2.0 Flash for minimal latency.

    Args:
        step:           The current step being verified
        lesson:         The full lesson (for next-step context)
        verdict:        The VisionVerdict from the Vision Agent
        recent_history: Optional last 3-4 conversation messages for context

    Returns:
        A short coaching message string (1-2 sentences, spoken aloud)
    """
    next_step = _get_next_step(step, lesson)

    if verdict.step_completed:
        status_context = (
            f"Step {step.order + 1} COMPLETED ✓ (confidence: {verdict.confidence:.0%}). "
            f"Next step: {next_step.instruction if next_step else 'This was the final step — great work!'}"
        )
    else:
        status_context = (
            f"Step {step.order + 1} NOT YET COMPLETE (confidence: {verdict.confidence:.0%}). "
            f"Issue observed: {verdict.error_detail or 'Could not determine specific issue.'}"
        )

    history_context = ""
    if recent_history:
        history_context = "\n\nRecent conversation:\n" + "\n".join(
            f"{m.role.upper()}: {m.content}" for m in recent_history[-4:]
        )

    prompt = (
        f"Lesson: {lesson.title}\n"
        f"Current Step: {step.instruction}\n"
        f"Success Criteria: {step.success_criteria}\n"
        f"Status: {status_context}"
        f"{history_context}\n\n"
        f"Write a short coaching message for the learner now."
    )

    response = await asyncio.to_thread(
        _client.models.generate_content,
        model=MODEL,
        contents=prompt,
        config=types.GenerateContentConfig(
            system_instruction=COACHING_SYSTEM,
            max_output_tokens=200,
            temperature=0.7,
        ),
    )

    return response.text.strip()


async def converse(
    step: Step,
    lesson: Lesson,
    conversation_history: List[ConversationMessage],
    user_message: str,
    frame_b64: Optional[str] = None,
) -> tuple[str, List[ConversationMessage]]:
    """
    Handle a full conversational turn with the learner (/coach endpoint).
    Powered by Gemini 2.0 Flash for instant voice-ready responses.

    Args:
        step:                 Current step the learner is on
        lesson:               Full lesson
        conversation_history: Full conversation history so far
        user_message:         What the learner just said/asked
        frame_b64:            Optional base64 JPEG frame for visual context

    Returns:
        Tuple of (reply_text, updated_conversation_history)
    """
    system_with_context = (
        f"{CONVERSATION_SYSTEM}\n\n"
        f"Current Lesson: {lesson.title}\n"
        f"Description: {lesson.description}\n"
        f"Current Step ({step.order + 1} of {len(lesson.steps)}): {step.instruction}\n"
        f"Success Criteria: {step.success_criteria}"
    )

    # Build Gemini chat history
    gemini_history = _history_to_gemini(conversation_history)

    # Build the new user message content (with optional frame)
    if frame_b64:
        image_bytes = base64.b64decode(frame_b64)
        user_parts = [
            types.Part.from_bytes(data=image_bytes, mime_type="image/jpeg"),
            types.Part.from_text(text=user_message),
        ]
    else:
        user_parts = [types.Part.from_text(text=user_message)]

    # Append new user message to history before generating
    new_user_msg = ConversationMessage(role="user", content=user_message)
    updated_history = list(conversation_history) + [new_user_msg]

    # Run Gemini chat in thread pool (SDK is sync)
    def _run_chat() -> str:
        chat = _client.chats.create(
            model=MODEL,
            config=types.GenerateContentConfig(
                system_instruction=system_with_context,
                max_output_tokens=400,
                temperature=0.8,
            ),
            history=gemini_history,
        )
        response = chat.send_message(user_parts)
        return response.text.strip()

    reply_text = await asyncio.to_thread(_run_chat)

    # Append assistant reply to history
    updated_history.append(ConversationMessage(role="assistant", content=reply_text))

    return reply_text, updated_history


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _get_next_step(current_step: Step, lesson: Lesson) -> Optional[Step]:
    """Return the step after the current one, or None if last step."""
    try:
        return next(s for s in lesson.steps if s.order == current_step.order + 1)
    except StopIteration:
        return None


def _history_to_gemini(history: List[ConversationMessage]) -> list:
    """Convert ConversationMessage list to Gemini SDK Content format."""
    gemini_history = []
    for msg in history:
        role = "user" if msg.role == "user" else "model"
        gemini_history.append(
            types.Content(
                role=role,
                parts=[types.Part.from_text(text=msg.content)],
            )
        )
    return gemini_history
