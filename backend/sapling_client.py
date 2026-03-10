import os
import requests


SAPLING_API_URL = "https://api.sapling.ai/api/v1/aidetect"
SAPLING_API_KEY = os.getenv("SAPLING_API_KEY")


def detect_text_sapling(text: str):
    """
    Calls Sapling AI Detection API.
    Returns standardized raw_result dict.
    """

    if not SAPLING_API_KEY:
        return {
            "error": "Sapling API key not configured."
        }

    try:
        response = requests.post(
            SAPLING_API_URL,
            headers={
                "Authorization": f"Bearer {SAPLING_API_KEY}",
                "Content-Type": "application/json",
            },
            json={"text": text},
            timeout=15
        )

        response.raise_for_status()

        data = response.json()

        # Sapling returns score between 0–1
        ai_score = float(data.get("score", 0))

        label = (
            "Strong AI generation indicators"
            if ai_score >= 0.75 else
            "Moderate AI signals detected"
            if ai_score >= 0.45 else
            "Likely human-authored content"
        )

        return {
            "label": label,
            "confidence": ai_score,
            "ai_confidence": round(ai_score * 100, 2),
            "model": "Sapling AI Detector",
            "sentence_scores": data.get("sentence_scores", []),
            "raw_response": data,
        }

    except requests.exceptions.RequestException as e:
        return {
            "error": f"Sapling API request failed: {str(e)}"
        }

    except Exception as e:
        return {
            "error": f"Unexpected error: {str(e)}"
        }
