from agents.conversation_coach import coach_conversation
from main import load_lesson
import asyncio

lesson = load_lesson("2778009b-2f8e-4172-a504-a65aebc6c8d4")
step = lesson.steps[0]

result = coach_conversation(
    user_message="System: We just started the lesson. Provide a brief greeting.",
    conversation_history=[],
    frame_b64=None,
    step=step,
    lesson_title=lesson.title
)
print(result)
