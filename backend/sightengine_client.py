import os
import requests
from dotenv import load_dotenv

load_dotenv()

# 🔐 Load credentials securely
API_USER = os.getenv("SIGHTENGINE_API_USER")
API_SECRET = os.getenv("SIGHTENGINE_API_SECRET")

BASE_URL = "https://api.sightengine.com/1.0/check.json"


def detect_image_sightengine(image_bytes: bytes, timeout_seconds: int = 25) -> dict:
    """
    Sends image to Sightengine GenAI detector.

    Guaranteed return shape:
    {
        ai_score: float (0.0 – 1.0),
        generators: { model_name: probability },
        raw: full_response OR None,
        error: optional
    }
    """

    # 1️⃣ Credentials check
    if not API_USER or not API_SECRET:
        return {
            "error": "Sightengine credentials not configured",
            "ai_score": 0.0,
            "generators": {},
            "raw": None,
        }

    files = {
        "media": ("image.jpg", image_bytes),
    }

    data = {
        "models": "genai",
        "api_user": API_USER,
        "api_secret": API_SECRET,
    }

    # 2️⃣ Network safety
    try:
        response = requests.post(
            BASE_URL,
            files=files,
            data=data,
            timeout=timeout_seconds,
        )
    except requests.RequestException as e:
        return {
            "error": "Sightengine request failed",
            "detail": str(e),
            "ai_score": 0.0,
            "generators": {},
            "raw": None,
        }

    # 3️⃣ HTTP safety
    if response.status_code != 200:
        return {
            "error": "Sightengine API error",
            "detail": response.text,
            "ai_score": 0.0,
            "generators": {},
            "raw": None,
        }

    result = response.json()

    # 4️⃣ Extract AI probability safely
    type_block = result.get("type", {})
    ai_score = type_block.get("ai_generated")

    if not isinstance(ai_score, (int, float)):
        ai_score = 0.0

    ai_score = max(0.0, min(float(ai_score), 1.0))

    # 5️⃣ Extract generator breakdown (dashboard-style)
    generators = {}

    for category in ("diffusion", "gan"):
        models = type_block.get(category)
        if isinstance(models, dict):
            for name, score in models.items():
                if isinstance(score, (int, float)):
                    generators[name] = max(0.0, min(float(score), 1.0))

    return {
        "ai_score": ai_score,
        "generators": generators,
        "raw": result,
    }
