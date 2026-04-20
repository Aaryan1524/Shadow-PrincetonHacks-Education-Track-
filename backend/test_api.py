import requests
import base64

res = requests.get("http://localhost:8000/lessons")
lessons = res.json()
if lessons:
    lesson_id = lessons[0]["id"]
    print("Lesson ID:", lesson_id)
else:
    print("No lessons")

