#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BACKEND_DIR="$ROOT_DIR/backend"

if [ ! -d "$BACKEND_DIR" ]; then
  echo "❌ Backend not found at: $BACKEND_DIR"
  echo "Please place backend code under CoachingApp/backend"
  exit 1
fi

cd "$BACKEND_DIR"
if [ -d venv ]; then
  source venv/bin/activate
fi

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"

exec uvicorn main:app --host "$HOST" --port "$PORT"
