import io
import math
from typing import Any, Dict, Optional
from functools import lru_cache

import numpy as np
from fastapi import FastAPI, File, Request, UploadFile, HTTPException
from pydantic import BaseModel

from cache import set_cached_result
from explainability.engine import ExplainabilityEngine
from rate_limit import check_rate_limit
from sightengine_client import detect_image_sightengine


app = FastAPI(title="Detectify AI API")

MAX_TEXT_CHARS = 4000
MAX_IMAGE_BYTES = 10 * 1024 * 1024
MAX_AUDIO_BYTES = 25 * 1024 * 1024
MAX_VIDEO_BYTES = 80 * 1024 * 1024


@lru_cache(maxsize=1)
def _detectors_module():
    # Lazy import prevents heavy model loading during startup.
    import detectors
    return detectors


def clean_for_json(obj: Any) -> Any:
    if isinstance(obj, np.ndarray):
        return obj.tolist()
    if isinstance(obj, (np.float32, np.float64)):
        return float(obj)
    if isinstance(obj, (np.int32, np.int64)):
        return int(obj)
    if isinstance(obj, dict):
        return {k: clean_for_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [clean_for_json(i) for i in obj]
    return obj


def clean_json(obj: Any) -> Any:
    if isinstance(obj, float):
        if math.isnan(obj) or math.isinf(obj):
            return 0
    if isinstance(obj, dict):
        return {k: clean_json(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [clean_json(v) for v in obj]
    return obj


def _to_float(value: Any, fallback: float = 0.0) -> float:
    try:
        num = float(value)
    except Exception:
        return fallback
    if math.isnan(num) or math.isinf(num):
        return fallback
    return num


def _confidence_tier(ai_percent: float) -> str:
    if ai_percent >= 80:
        return "Strong AI indicators"
    if ai_percent >= 60:
        return "Moderate AI indicators"
    if ai_percent >= 40:
        return "Mixed signals"
    return "Low confidence"


def _normalize_response(
    media_type: str,
    raw_result: Optional[Dict[str, Any]] = None,
    *,
    success: bool = True,
    error: Optional[str] = None,
    detail: Optional[str] = None,
    mode: str = "accurate",
) -> Dict[str, Any]:
    payload: Dict[str, Any] = dict(raw_result or {})

    ai = _to_float(payload.get("ai_probability", payload.get("ai_confidence", 0 if success else 50)))
    ai = max(0.0, min(ai, 100.0))
    human = _to_float(payload.get("human_probability", 100 - ai), 100 - ai)
    human = max(0.0, min(human, 100.0))

    response: Dict[str, Any] = {
        "success": success,
        "type": media_type,
        "mode": mode,
        "label": payload.get("label") or ("Analysis unavailable" if not success else f"Likely human {media_type}"),
        "ai_probability": round(ai, 2),
        "human_probability": round(human, 2),
        "confidence": payload.get("confidence") or _confidence_tier(ai),
        "method": payload.get("method", "Detectify"),
    }

    for key in ("signals", "generators", "raw_response"):
        if key in payload:
            response[key] = payload.get(key)

    for key, value in payload.items():
        if key not in response:
            response[key] = value

    if success:
        explainability = ExplainabilityEngine.generate(
            media_type=media_type,
            raw_result=response,
        )
    else:
        explainability = {
            "version": "fallback-1.0",
            "summary": "Analysis could not complete reliably. Showing fallback output.",
            "model_reasoning": [error or "Unexpected detector error."],
        }

    response["explainability"] = explainability

    if error:
        response["error"] = error
    if detail:
        response["detail"] = detail

    return clean_for_json(clean_json(response))


def rate_limit_dependency(request: Request) -> None:
    client_ip = request.headers.get("x-forwarded-for", request.client.host)
    if not check_rate_limit(client_ip):
        raise HTTPException(
            status_code=429,
            detail="Too many requests. Please wait before retrying.",
        )


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


class TextRequest(BaseModel):
    text: str


@app.post("/detect/text")
def detect_text_api(req: TextRequest, mode: str = "accurate") -> Dict[str, Any]:
    try:
        if len(req.text.strip()) > MAX_TEXT_CHARS:
            return _normalize_response(
                "text",
                success=False,
                error=f"Text too long. Maximum {MAX_TEXT_CHARS} characters allowed.",
                mode=mode,
            )
        raw_result = _detectors_module().detect_text(req.text, mode=mode)
        if "error" in raw_result:
            return _normalize_response(
                "text",
                raw_result,
                success=False,
                error=str(raw_result.get("error", "Text detector error")),
                mode=mode,
            )
        return _normalize_response("text", raw_result, success=True, mode=mode)
    except Exception as e:
        return _normalize_response("text", success=False, error="Text detection failed", detail=str(e), mode=mode)


@app.post("/detect/image")
async def detect_image_api(file: UploadFile = File(...), mode: str = "accurate") -> Dict[str, Any]:
    try:
        image_bytes = await file.read()
        if len(image_bytes) > MAX_IMAGE_BYTES:
            return _normalize_response(
                "image",
                success=False,
                error=f"Image too large. Maximum {MAX_IMAGE_BYTES // (1024 * 1024)} MB allowed.",
                mode=mode,
            )
        image_timeout = 6 if str(mode).lower() == "fast" else 12
        detector_result = detect_image_sightengine(image_bytes, timeout_seconds=image_timeout)

        if "error" in detector_result:
            if str(mode).lower() == "accurate":
                try:
                    local_result = _detectors_module().detect_image(io.BytesIO(image_bytes))
                    local_result["method"] = "Local fallback (accurate)"
                    return _normalize_response("image", local_result, success=True, mode=mode)
                except Exception:
                    pass
            return _normalize_response(
                "image",
                success=False,
                error=str(detector_result.get("error", "Image detector error")),
                detail=str(detector_result.get("detail", "")),
                mode=mode,
            )

        ai_score = _to_float(detector_result.get("ai_score", 0.0), 0.0)

        # Accurate mode: blend external + local model when confidence is borderline.
        if str(mode).lower() == "accurate" and 0.35 <= ai_score <= 0.75:
            try:
                local_result = _detectors_module().detect_image(io.BytesIO(image_bytes))
                local_ai = _to_float(local_result.get("ai_probability", 50.0), 50.0) / 100.0
                ai_score = (ai_score * 0.7) + (local_ai * 0.3)
            except Exception:
                pass
        ai_percent = round(max(0.0, min(ai_score, 1.0)) * 100, 2)

        raw_result = {
            "label": "AI-generated image" if ai_percent >= 50 else "Likely real image",
            "ai_probability": ai_percent,
            "human_probability": round(100 - ai_percent, 2),
            "confidence": _confidence_tier(ai_percent),
            "method": f"Sightengine GenAI ({'fast' if str(mode).lower() == 'fast' else 'accurate'})",
            "generators": detector_result.get("generators", {}),
            "raw_response": detector_result.get("raw"),
        }

        set_cached_result(image_bytes, raw_result)
        return _normalize_response("image", raw_result, success=True, mode=mode)
    except Exception as e:
        return _normalize_response("image", success=False, error="Image detection failed", detail=str(e), mode=mode)


@app.post("/detect/audio")
async def detect_audio_api(file: UploadFile = File(...), mode: str = "accurate") -> Dict[str, Any]:
    try:
        contents = await file.read()
        if len(contents) > MAX_AUDIO_BYTES:
            return _normalize_response(
                "audio",
                success=False,
                error=f"Audio too large. Maximum {MAX_AUDIO_BYTES // (1024 * 1024)} MB allowed.",
                mode=mode,
            )
        raw_result = _detectors_module().detect_audio(contents, mode=mode)
        if "error" in raw_result:
            return _normalize_response(
                "audio",
                raw_result,
                success=False,
                error=str(raw_result.get("error", "Audio detector error")),
                mode=mode,
            )
        return _normalize_response("audio", raw_result, success=True, mode=mode)
    except Exception as e:
        return _normalize_response("audio", success=False, error="Audio detection failed", detail=str(e), mode=mode)


@app.post("/detect/video")
async def detect_video_api(file: UploadFile = File(...), mode: str = "accurate") -> Dict[str, Any]:
    try:
        contents = await file.read()
        if len(contents) > MAX_VIDEO_BYTES:
            return _normalize_response(
                "video",
                success=False,
                error=f"Video too large. Maximum {MAX_VIDEO_BYTES // (1024 * 1024)} MB allowed.",
                mode=mode,
            )
        raw_result = _detectors_module().detect_video(io.BytesIO(contents), mode=mode)
        if "error" in raw_result:
            return _normalize_response(
                "video",
                raw_result,
                success=False,
                error=str(raw_result.get("error", "Video detector error")),
                mode=mode,
            )
        return _normalize_response("video", raw_result, success=True, mode=mode)
    except Exception as e:
        return _normalize_response("video", success=False, error="Video detection failed", detail=str(e), mode=mode)
