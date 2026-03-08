import hashlib
import time

CACHE_TTL = 60 * 60 * 24  # 24 hours

_cache = {}

def _hash_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def get_cached_result(image_bytes: bytes):
    key = _hash_bytes(image_bytes)
    entry = _cache.get(key)

    if not entry:
        return None

    if time.time() - entry["timestamp"] > CACHE_TTL:
        del _cache[key]
        return None

    return entry["result"]

def set_cached_result(image_bytes: bytes, result: dict):
    key = _hash_bytes(image_bytes)
    _cache[key] = {
        "timestamp": time.time(),
        "result": result,
    }
