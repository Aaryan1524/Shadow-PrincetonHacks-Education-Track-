"""
voice_coach.py — Gemini-based voice coaching agent for Shadow AR app.

Responsibilities:
  1. build_wav_from_pcm()  — wrap raw PCM-16 bytes into an in-memory WAV file
  2. transcribe_and_coach() — process audio through Gemini (STT + coaching LLM) + gTTS (TTS)
"""

import base64
import io
import os
import wave
from typing import Optional

from google import genai
from google.genai import types

# ── API key configuration ──────────────────────────────────────────────────────
# load_dotenv() has already run in main.py before this module is imported,
# so GOOGLE_API_KEY is in os.environ.
_client = genai.Client(api_key=os.environ.get("GOOGLE_API_KEY", ""))

_MODEL_NAME = "gemini-2.0-flash"

_SYSTEM_INSTRUCTION = """
You are Alex, a warm, funny, and genuinely helpful coach guiding someone through a hands-on task in real time. They're wearing AR glasses and can't look at a screen — you're their voice in their ear.

Your personality:
- Talk like a real person. Casual, natural, contractions. Not a robot, not a manual.
- Use humor when it fits. If they mess up: "Ha, okay — not quite, but you're close!" If they get it: "Yes! Exactly like that, nice work."
- Be warm and patient. Never make them feel dumb. If they're stuck: "This one's tricky, everyone fumbles it at first."
- Keep it SHORT. They have their hands full. 1-3 sentences max. Get to the point fast.
- Be SPECIFIC. Don't say "good job" — say what exactly was good or what exactly needs fixing.
- Vary your language. Never start replies the same way twice.
- You can hear their voice — respond to what they actually said, not a generic script.

What you never do:
- Never say "Certainly!", "Of course!", "Great question!" or any assistant-speak.
- Never lecture. Quick coaching moments only.
- Never repeat the step instruction back word for word.

Examples:
- "Hmm, tilt it a little more to the right — yeah, there you go."
- "Ha, happens to everyone. Make sure the lid clicks before you move on."
- "Okay that's perfect actually, you can move to the next one."
- "So the trick here is to go slow — if you rush this part, it gets messy later."
"""



# ── WAV builder ───────────────────────────────────────────────────────────────

def build_wav_from_pcm(pcm_bytes: bytes, sample_rate: int = 16000) -> bytes:
    """
    Wrap raw PCM-16-bit-mono bytes in a valid RIFF WAV container.

    Args:
        pcm_bytes:   Raw PCM samples, 16-bit little-endian, mono.
        sample_rate: Samples per second (default 16,000 — iOS mic standard).

    Returns:
        Complete WAV file as bytes (starts with b'RIFF').
    """
    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(1)    # mono
        wf.setsampwidth(2)    # 16-bit = 2 bytes per sample
        wf.setframerate(sample_rate)
        wf.writeframes(pcm_bytes)
    return buf.getvalue()


# ── Main coaching function ────────────────────────────────────────────────────

def transcribe_and_coach(
    wav_bytes: bytes,
    lesson_title: str,
    step: any,
    step_index: int,
    total_steps: int,
    conversation_history: list[dict],
    coach_response: Optional[dict],
) -> dict:
    """
    Send audio + lesson context to Gemini 1.5 Flash, then synthesise the reply
    as MP3 using gTTS.

    Args:
        wav_bytes:             In-memory WAV file (from build_wav_from_pcm).
        lesson_title:          e.g. "Make Coffee"
        step_instruction:      e.g. "Fill the kettle with water"
        success_criteria:      e.g. "Kettle is full and on the counter"
        step_index:            0-based index of the current step.
        total_steps:           Total number of steps in the lesson.
        conversation_history:  List of {"role": "user"|"model", "content": str}.
                               NOTE: uses "model" (not "assistant") as the AI role.
        coach_response:        The latest CoachResponse dict from /verify-step, or None.

    Returns:
        {
            "reply":            str   — coach's text reply,
            "audio_b64":        str   — base64-encoded MP3 (or None if gTTS failed),
            "updated_history":  list  — conversation_history + new user+model turns,
        }
    """
    # ── 1. Build the context text prompt ──────────────────────────────────────
    if coach_response:
        visual_context = (
            f"Latest AR visual analysis: "
            f"step completed={coach_response.get('step_completed', 'unknown')}, "
            f"confidence={coach_response.get('confidence', 0.0):.0%}, "
            f"coach note: \"{coach_response.get('coaching_message', '')}\""
        )
        if coach_response.get("error_detail"):
            visual_context += f", issue: \"{coach_response['error_detail']}\""
    else:
        visual_context = "No visual analysis available yet."

    blueprint_parts = [
        f"LESSON: {lesson_title}",
        f"CURRENT STEP ({step_index + 1} of {total_steps}): {getattr(step, 'instruction', str(step))}",
    ]
    
    # Extract rich metadata from the master blueprint schema if available
    meta_fields = {
        "EXPERT TECHNIQUE": getattr(step, 'technique_notes', ""),
        "PACE/TEMPO": getattr(step, 'tempo_description', ""),
        "SUCCESS LOOK": getattr(step, 'success_criteria', ""),
        "POTENTIAL MISTAKES": getattr(step, 'common_failure_points', ""),
        "FAILURE TRIGGERS": getattr(step, 'failure_triggers', ""),
    }
    for label, val in meta_fields.items():
        if val and str(val).strip():
            blueprint_parts.append(f"{label}: {val}")
    
    blueprint_parts.append(f"AI VISUAL ANALYSIS: {visual_context}")
    
    context_prompt = (
        "--- MASTER KNOWLEDGE BLUEPRINT ---\n" +
        "\n".join(blueprint_parts) +
        "\n----------------------------------\n\n"
        "The learner just said something (listen to the audio above). "
        "Respond as their coach — answer their question, give guidance, or "
        "encourage them using the blueprint details above. Keep it to 1-3 sentences."
    )

    # ── 2. Build Gemini content list ──────────────────────────────────────────
    # Previous turns from conversation_history (stored as Gemini-native dicts)
    gemini_history = []
    for turn in conversation_history:
        gemini_history.append(
            types.Content(
                role=turn["role"],          # "user" or "model"
                parts=[types.Part(text=turn["content"])],
            )
        )

    # Current user turn: audio blob + text context
    current_parts = [
        types.Part(
            inline_data=types.Blob(mime_type="audio/wav", data=wav_bytes)
        ),
        types.Part(text=context_prompt),
    ]
    current_content = types.Content(role="user", parts=current_parts)

    all_contents = gemini_history + [current_content]

    # ── 3. Call Gemini ────────────────────────────────────────────────────────
    try:
        response = _client.models.generate_content(
            model=_MODEL_NAME,
            contents=all_contents,
            config=types.GenerateContentConfig(
                system_instruction=_SYSTEM_INSTRUCTION,
                max_output_tokens=10000,
                temperature=0.9,
            ),
        )
        reply = response.text.strip()
    except Exception as exc:
        raise RuntimeError(f"Gemini API error: {type(exc).__name__}: {exc}") from exc

    # ── 4. Text-to-speech via gTTS ────────────────────────────────────────────
    # gTTS makes a network call to translate.google.com — no auth required.
    # Runs in the same thread (caller already offloaded us via asyncio.to_thread).
    audio_b64: Optional[str] = None
    try:
        from gtts import gTTS  # lazy import; gTTS must be pip-installed

        buf = io.BytesIO()
        tts = gTTS(text=reply, lang="en", slow=False)
        tts.write_to_fp(buf)
        buf.seek(0)
        audio_b64 = base64.b64encode(buf.read()).decode("utf-8")
    except Exception as tts_exc:
        # Non-fatal: caller will still send the text reply
        print(f"gTTS error (non-fatal): {type(tts_exc).__name__}: {tts_exc}")

    # ── 5. Build updated history ──────────────────────────────────────────────
    # We cannot store the WAV audio in history (too large, not text).
    # Store a placeholder in the user turn so context is preserved.
    updated_history = list(conversation_history)
    updated_history.append({"role": "user", "content": "[audio message]"})
    updated_history.append({"role": "model", "content": reply})

    return {
        "reply": reply,
        "audio_b64": audio_b64,          # None if gTTS failed
        "updated_history": updated_history,
    }
