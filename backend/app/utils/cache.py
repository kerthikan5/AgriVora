"""
**Cache Utility**
Responsible for: Application-wide caching to reduce external API hits (e.g. SoilGrids, Open-Meteo).
"""

import time

# Simple in-memory cache
_cache = {}
TTL_SECONDS = 24 * 60 * 60  # 24 hours

def get_cache(key: str):
    entry = _cache.get(key)
    if not entry:
        return None

    value, timestamp = entry
    if time.time() - timestamp > TTL_SECONDS:
        del _cache[key]
        return None

    return value

def set_cache(key: str, value):
    _cache[key] = (value, time.time())
