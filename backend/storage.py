"""
storage.py — Shadow Backend JSON File I/O
Pure utility layer — no AI logic here.
Lessons are stored as individual JSON files in the lessons/ directory.
"""

from __future__ import annotations
import json
import os
from pathlib import Path
from typing import List

from models import Lesson

# ---------------------------------------------------------------------------
# Directory setup
# ---------------------------------------------------------------------------

LESSONS_DIR = Path(os.getenv("LESSONS_DIR", "./lessons"))
LESSONS_DIR.mkdir(parents=True, exist_ok=True)


def _lesson_path(lesson_id: str) -> Path:
    return LESSONS_DIR / f"{lesson_id}.json"


# ---------------------------------------------------------------------------
# Public helpers
# ---------------------------------------------------------------------------

def save_lesson(lesson: Lesson) -> None:
    """Persist a lesson to disk as JSON."""
    path = _lesson_path(lesson.id)
    with open(path, "w", encoding="utf-8") as f:
        f.write(lesson.model_dump_json(indent=2))


def load_lesson(lesson_id: str) -> Lesson:
    """
    Load a lesson from disk by its ID.
    Raises FileNotFoundError if the lesson does not exist.
    """
    path = _lesson_path(lesson_id)
    if not path.exists():
        raise FileNotFoundError(f"Lesson '{lesson_id}' not found")
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)
    return Lesson(**data)


def list_lessons() -> List[Lesson]:
    """Return all lessons stored on disk, sorted by created_at descending."""
    lessons: List[Lesson] = []
    for path in LESSONS_DIR.glob("*.json"):
        try:
            with open(path, "r", encoding="utf-8") as f:
                data = json.load(f)
            lessons.append(Lesson(**data))
        except Exception:
            # Skip malformed files silently
            continue
    lessons.sort(key=lambda l: l.created_at, reverse=True)
    return lessons


def delete_lesson(lesson_id: str) -> bool:
    """Delete a lesson file. Returns True if deleted, False if not found."""
    path = _lesson_path(lesson_id)
    if path.exists():
        path.unlink()
        return True
    return False
