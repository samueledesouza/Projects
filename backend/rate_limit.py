import time
from collections import defaultdict

REQUEST_LIMIT = 20          # max requests
WINDOW_SECONDS = 60         # per window (seconds)

_requests = defaultdict(list)

def check_rate_limit(client_ip: str) -> bool:
    """
    Returns:
        True  -> request allowed
        False -> rate limit exceeded
    """

    now = time.time()
    timestamps = _requests[client_ip]

    # Keep only requests inside the time window
    timestamps = [t for t in timestamps if now - t < WINDOW_SECONDS]
    _requests[client_ip] = timestamps

    if len(timestamps) >= REQUEST_LIMIT:
        return False

    _requests[client_ip].append(now)
    return True
