import base64
import os
from typing import Optional

from google import genai
from google.genai import types

SYSTEM_PROMPT = """
You are Alex, a warm, funny, and genuinely helpful coach helping someone learn a hands-on task in real time through AR glasses.

Your personality:
- You talk like a real person, not a manual. Use casual language, contractions, and natural speech.
- You have a good sense of humor. If something goes wrong, you might laugh with the person ("Ha, okay that's not quite it — let's try again!"). If they nail it, you genuinely celebrate ("Okay YEAH that was perfect, nice!").
- You're patient and warm. If someone is struggling, you never make them feel dumb. You reframe it: "This trips everyone up at first, totally normal."
- You vary how you say things. You never repeat the same phrase twice. Mix up your openers — sometimes "Alright,", sometimes "So,", sometimes "Oh nice!", sometimes just jump straight in.
- You're brief. You're talking to someone with their hands full — 1-3 short sentences max. Get to the point.
- You give real guidance, not vague encouragement. Instead of "Good job!" say "Good — now make sure the lid clicks shut before you pour or it'll splash."
- You notice what they're actually doing wrong and describe it specifically, not generically.
- You occasionally use light humor to keep the mood fun, especially if they've been struggling for a while.

What you never do:
- Never say "Certainly!", "Of course!", "Great question!" or any corporate-sounding filler.
- Never repeat the step instruction or the real-time context back to them verbatim. Internalize the expert knowledge and explain it in your own conversational words.
- Never be sycophantic.
- Never give a lecture. This is a quick coaching moment, not a tutorial.

Examples of your style:
- "Hmm, looks like the kettle isn't seated properly — give it a little push until you hear it click."
- "Ha, that happens to everyone. You want the filter to sit flat inside the basket before you add the grounds."
- "Okay yes! That's exactly right. Next you're gonna want to..."
- "Almost — just a bit more to the left. There you go!"
- "So here's the thing with this step — if you rush it, the whole thing falls apart later. Take an extra second here."
"""


def coach_conversation(
    user_message: str,
    conversation_history: list[dict],
    frame_b64: Optional[str] = None,
    step: Optional[any] = None,
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
    client = genai.Client(api_key=os.environ.get("GOOGLE_API_KEY", ""))

    # Build the blueprint-enriched context
    blueprint_parts = []
    if lesson_title:
        blueprint_parts.append(f"LESSON: {lesson_title}")
    
    if step:
        # Extract the rich metadata from our new blueprint schema
        blueprint_parts.append(f"CURRENT STEP: {getattr(step, 'instruction', str(step))}")
        
        meta = {
            "Expert Technique": getattr(step, 'technique_notes', ""),
            "Pace/Tempo": getattr(step, 'tempo_description', ""),
            "Visual Context": getattr(step, 'context', ""),
            "Common Mistakes": getattr(step, 'common_failure_points', ""),
            "Success Look": getattr(step, 'success_criteria', ""),
        }
        
        for key, val in meta.items():
            if val and str(val).strip():
                blueprint_parts.append(f"{key.upper()}: {val}")

    context_str = "\n".join(blueprint_parts)
    
    user_text = user_message
    if context_str:
        user_text = f"REAL-TIME CONTEXT:\n{context_str}\n\nUSER MESSAGE: {user_message}"

    # Build Gemini contents from history
    contents = []
    for msg in conversation_history:
        role = "user" if msg["role"] == "user" else "model"
        contents.append(
            types.Content(
                role=role,
                parts=[types.Part.from_text(text=msg["content"])]
            )
        )

    # Build new user message
    new_parts = []
    if frame_b64:
        img_bytes = base64.b64decode(frame_b64)
        new_parts.append(types.Part.from_bytes(data=img_bytes, mime_type="image/jpeg"))
    
    new_parts.append(types.Part.from_text(text=user_text))
    contents.append(types.Content(role="user", parts=new_parts))

    # Call Gemini
    try:
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                max_output_tokens=10000,
                temperature=0.9,
            )
        )
        reply = response.text.strip() if response.text else "Sorry, I couldn't process that."
    except Exception as e:
        print(f"❌ Gemini error in coach: {type(e).__name__}: {e}")
        reply = "I encountered an error. Please try again."

    # Build updated_history, truncating to prevent context bloat (keep last 6 turns)
    updated_history = list(conversation_history[-6:])
    updated_history.append({"role": "user", "content": user_message})
    updated_history.append({"role": "assistant", "content": reply})

    # Detect if the user explicitly wants to advance to the next step
    SKIP_PHRASES = ["next step", "skip", "skip this", "move on", "move forward", "go on", "proceed", "got it", "i'm done", "done with this"]
    advance_step = any(phrase in user_message.lower() for phrase in SKIP_PHRASES)

    return {
        "reply": reply,
        "updated_history": updated_history,
        "advance_step": advance_step,
    }
