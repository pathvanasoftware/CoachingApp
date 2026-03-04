import json
import os
from datetime import datetime, timezone
from pathlib import Path

from fastapi import APIRouter

router = APIRouter()

_APP_DIR = Path(__file__).resolve().parents[1]
_DEFAULT_BUILD_INFO_PATH = _APP_DIR / "build_info.json"
_SERVICE_STARTED_AT = datetime.now(timezone.utc).isoformat()


def _read_build_info() -> dict:
    build_info_path = Path(os.getenv("BUILD_INFO_PATH", str(_DEFAULT_BUILD_INFO_PATH)))
    if not build_info_path.exists():
        return {}
    try:
        with build_info_path.open("r", encoding="utf-8") as f:
            data = json.load(f)
            return data if isinstance(data, dict) else {}
    except Exception:
        return {}


def _resolve_git_sha(build_info: dict) -> str:
    sha_candidates = [
        os.getenv("RAILWAY_GIT_COMMIT_SHA"),
        os.getenv("GITHUB_SHA"),
        os.getenv("COMMIT_SHA"),
        build_info.get("git_sha") if isinstance(build_info, dict) else None,
    ]
    for value in sha_candidates:
        if value and isinstance(value, str):
            return value
    return "unknown"


def _resolve_deployed_at(build_info: dict) -> str:
    deployed_candidates = [
        os.getenv("RAILWAY_DEPLOYMENT_CREATED_AT"),
        os.getenv("DEPLOYED_AT"),
        os.getenv("BUILD_TIMESTAMP"),
        build_info.get("deployed_at") if isinstance(build_info, dict) else None,
    ]
    for value in deployed_candidates:
        if value and isinstance(value, str):
            return value
    return _SERVICE_STARTED_AT

@router.get("/health")
async def health_check():
    build_info = _read_build_info()
    git_sha = _resolve_git_sha(build_info)
    return {
        "status": "ok",
        "git_sha": git_sha,
        "git_sha_short": git_sha[:12] if git_sha != "unknown" else "unknown",
        "deployed_at": _resolve_deployed_at(build_info),
    }
