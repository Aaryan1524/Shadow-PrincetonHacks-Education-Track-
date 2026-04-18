import os
from typing import Optional

import anthropic

SYSTEM_PROMPT = (
    "You are a helpful coaching assistant for a hands-on learning task. "
    "Be concise, encouraging, and specific. Keep responses to 1-2 sentences."
)


def coach_conversation(
    user_message: str,
    conversation_history: list[dict],
    frame_b64: Optional[str] = None,
    step_instruction: Optional[str] = None,
    lesson_title: Optional[str] = None,
) -> dict:
    """
    Generate a coaching response using Claude.

    Args:
        user_message: What the learner asked or said.
        conversation_history: List of {"role": "user"|"assistant", "content": "..."}.
        frame_b64: Optional base64-encoded JPEG for visual context.
        step_instruction: The current step instruction for context tagging.
        lesson_title: Title of the lesson for context tagging.

    Returns:
        {"reply": str, "updated_history": List[dict]}
    """
    client = anthropic.Anthropic()

    # Build the context-enriched user text
    context_parts = []
    if lesson_title:
        context_parts.append(f"Lesson: {lesson_title}")
    if step_instruction:
        context_parts.append(f"Current step: {step_instruction}")
    context_str = " | ".join(context_parts)

    if context_str:
        user_text = f"{user_message} [Context: {context_str}]"
    else:
        user_text = user_message

    # Build Claude messages from history
    messages = [
        {"role": msg["role"], "content": msg["content"]}
        for msg in conversation_history
    ]

    # Build new user message content
    if frame_b64:
        new_user_content = [
            {
                "type": "image",
                "source": {
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": frame_b64,
                },
            },
            {"type": "text", "text": user_text},
        ]
    else:
        new_user_content = user_text

    messages.append({"role": "user", "content": new_user_content})

    # Call Claude
    try:
        response = client.messages.create(
            model="claude-sonnet-4-6",
            max_tokens=300,
            system=SYSTEM_PROMPT,
            messages=messages,
        )
        reply = response.content[0].text.strip()
    except Exception as e:
        print(f"❌ Claude error in coach: {type(e).__name__}: {e}")
        reply = "I encountered an error. Please try again."

    # Build updated_history
    updated_history = list(conversation_history)
    updated_history.append({"role": "user", "content": user_message})
    updated_history.append({"role": "assistant", "content": reply})

    return {
        "reply": reply,
        "updated_history": updated_history,
    }
