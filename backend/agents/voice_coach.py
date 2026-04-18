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

import google.generativeai as genai
from google.generativeai import protos

# ── API key configuration ──────────────────────────────────────────────────────
# load_dotenv() has already run in main.py before this module is imported,
# so GOOGLE_API_KEY is in os.environ.
genai.configure(api_key=os.environ.get("GOOGLE_API_KEY", ""))

_MODEL_NAME = "gemini-3.1-flash-lite-preview"

_SYSTEM_INSTRUCTION = (
    "You are a voice coaching assistant for a hands-on learning task. "
    "The learner is wearing AR glasses and you are their real-time audio guide. "
    "Be conversational, encouraging, and concise. "
    "Speak naturally as if talking to the learner in person."
)


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
    step_instruction: str,
    success_criteria: str,
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

    context_prompt = (
        f"Lesson: {lesson_title}\n"
        f"Current step ({step_index + 1} of {total_steps}): {step_instruction}\n"
        f"Success criteria: {success_criteria}\n"
        f"{visual_context}\n\n"
        "The learner just said something (listen to the audio above). "
        "Respond as their coach — answer their question, give guidance, or "
        "encourage them. Keep your response to 1-3 sentences."
    )

    # ── 2. Build Gemini content list ──────────────────────────────────────────
    # Previous turns from conversation_history (stored as Gemini-native dicts)
    gemini_history = []
    for turn in conversation_history:
        gemini_history.append({
            "role": turn["role"],          # "user" or "model"
            "parts": [turn["content"]],    # Gemini parts are lists
        })

    # Current user turn: audio blob + text context (both in the same Content)
    current_parts = [
        protos.Part(inline_data=protos.Blob(mime_type="audio/wav", data=wav_bytes)),
        protos.Part(text=context_prompt),
    ]
    current_content = protos.Content(role="user", parts=current_parts)

    all_contents = gemini_history + [current_content]

    # ── 3. Call Gemini ────────────────────────────────────────────────────────
    model = genai.GenerativeModel(
        model_name=_MODEL_NAME,
        system_instruction=_SYSTEM_INSTRUCTION,
    )

    try:
        response = model.generate_content(
            contents=all_contents,
            generation_config={"max_output_tokens": 200, "temperature": 0.7},
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
