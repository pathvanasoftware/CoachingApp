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

# Ensure python exists
if ! command -v python3 >/dev/null 2>&1; then
  echo "❌ python3 not found. Install Python 3.10+ first."
  exit 1
fi

# Create venv if missing
if [ ! -d venv ]; then
  echo "ℹ️ Creating virtualenv..."
  python3 -m venv venv
fi

source venv/bin/activate

# Install deps if uvicorn missing or force install requested
if ! command -v uvicorn >/dev/null 2>&1 || [ "${FORCE_INSTALL:-0}" = "1" ]; then
  echo "ℹ️ Installing backend dependencies..."
  python -m pip install --upgrade pip
  python -m pip install -r requirements.txt
fi

export HOST="${HOST:-0.0.0.0}"
export PORT="${PORT:-8000}"

echo "✅ Starting backend at http://$HOST:$PORT"
exec uvicorn main:app --host "$HOST" --port "$PORT"
