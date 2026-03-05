import asyncio
import json
import logging
import os
import threading
import time
from typing import Any, Dict, Optional

logger = logging.getLogger(__name__)


def _env_bool(name: str, default: bool) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


class CacheBackend:
    async def get_json(self, key: str) -> Optional[Dict[str, Any]]:
        raise NotImplementedError

    async def set_json(self, key: str, value: Dict[str, Any], ttl_seconds: int) -> bool:
        raise NotImplementedError

    async def acquire_lock(self, key: str, owner: str, ttl_seconds: int) -> bool:
        raise NotImplementedError

    async def release_lock(self, key: str, owner: str) -> None:
        raise NotImplementedError


class NoopCache(CacheBackend):
    async def get_json(self, key: str) -> Optional[Dict[str, Any]]:
        return None

    async def set_json(self, key: str, value: Dict[str, Any], ttl_seconds: int) -> bool:
        return False

    async def acquire_lock(self, key: str, owner: str, ttl_seconds: int) -> bool:
        return True

    async def release_lock(self, key: str, owner: str) -> None:
        return None


class InMemoryCache(CacheBackend):
    def __init__(self) -> None:
        self._values: Dict[str, tuple[float, Dict[str, Any]]] = {}
        self._locks: Dict[str, tuple[float, str]] = {}
        self._mutex = threading.Lock()

    def _cleanup_locked(self) -> None:
        now = time.monotonic()
        stale_values = [k for k, (exp, _) in self._values.items() if exp <= now]
        for key in stale_values:
            self._values.pop(key, None)

        stale_locks = [k for k, (exp, _) in self._locks.items() if exp <= now]
        for key in stale_locks:
            self._locks.pop(key, None)

    async def get_json(self, key: str) -> Optional[Dict[str, Any]]:
        with self._mutex:
            self._cleanup_locked()
            entry = self._values.get(key)
            if not entry:
                return None
            _, value = entry
            return json.loads(json.dumps(value, ensure_ascii=False))

    async def set_json(self, key: str, value: Dict[str, Any], ttl_seconds: int) -> bool:
        ttl = max(1, int(ttl_seconds))
        with self._mutex:
            self._cleanup_locked()
            self._values[key] = (time.monotonic() + ttl, json.loads(json.dumps(value, ensure_ascii=False)))
            return True

    async def acquire_lock(self, key: str, owner: str, ttl_seconds: int) -> bool:
        ttl = max(1, int(ttl_seconds))
        with self._mutex:
            self._cleanup_locked()
            if key in self._locks:
                return False
            self._locks[key] = (time.monotonic() + ttl, owner)
            return True

    async def release_lock(self, key: str, owner: str) -> None:
        with self._mutex:
            self._cleanup_locked()
            existing = self._locks.get(key)
            if not existing:
                return
            _, current_owner = existing
            if current_owner == owner:
                self._locks.pop(key, None)


class RedisCache(CacheBackend):
    def __init__(self, redis_url: str) -> None:
        try:
            from redis.asyncio import Redis
        except Exception as exc:  # pragma: no cover - handled by factory fallback
            raise RuntimeError("redis package is not available") from exc

        self._client = Redis.from_url(redis_url, encoding="utf-8", decode_responses=True)

    async def get_json(self, key: str) -> Optional[Dict[str, Any]]:
        raw = await self._client.get(key)
        if not raw:
            return None
        try:
            parsed = json.loads(raw)
            return parsed if isinstance(parsed, dict) else None
        except Exception:
            return None

    async def set_json(self, key: str, value: Dict[str, Any], ttl_seconds: int) -> bool:
        ttl = max(1, int(ttl_seconds))
        payload = json.dumps(value, ensure_ascii=False)
        return bool(await self._client.set(key, payload, ex=ttl))

    async def acquire_lock(self, key: str, owner: str, ttl_seconds: int) -> bool:
        ttl = max(1, int(ttl_seconds))
        return bool(await self._client.set(key, owner, ex=ttl, nx=True))

    async def release_lock(self, key: str, owner: str) -> None:
        current = await self._client.get(key)
        if current == owner:
            await self._client.delete(key)


def build_cache_backend() -> CacheBackend:
    if not _env_bool("CACHE_ENABLED", True):
        logger.info("Cache disabled via CACHE_ENABLED=false")
        return NoopCache()

    redis_url = os.getenv("REDIS_URL", "").strip()
    if redis_url:
        try:
            backend = RedisCache(redis_url)
            logger.info("Cache backend: redis")
            return backend
        except Exception as exc:
            logger.warning("Redis cache unavailable, falling back to in-memory cache: %s", exc)

    logger.info("Cache backend: in-memory")
    return InMemoryCache()
