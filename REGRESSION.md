# CoachingApp UI Regression (3-minute checklist)

This checklist validates critical user flows after UI or state-management changes.

## Prerequisites

```bash
cd /Users/jianpinghuang/projects/CoachingApp
```

- Xcode + iOS Simulator installed
- iPhone 17 Pro simulator available

## 0) Build app

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project CoachingApp.xcodeproj \
  -scheme CoachingApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

Expected: `** BUILD SUCCEEDED **`

## 1) Start backend (self-healing)

```bash
./scripts/start_backend.sh
```

What it does:
- Creates `backend/venv` if missing
- Installs deps if needed
- Starts at `http://0.0.0.0:8000`

Health check:

```bash
curl -s http://localhost:8000/
```

Expected JSON:

```json
{"status":"ok","service":"CoachingApp API"}
```

## 2) Install app to simulator

```bash
APP="$HOME/Library/Developer/Xcode/DerivedData/CoachingApp-aoaqjitfdjimlkakhjhrrnzgodon/Build/Products/Debug-iphonesimulator/CoachingApp.app"
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl install booted "$APP"
```

## 3) Tab-level smoke screenshots

```bash
mkdir -p ~/.openclaw/workspace/artifacts

# Home
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=home
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/reg-home.png

# Sessions
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=sessions
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/reg-sessions.png

# Goals
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=goals
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/reg-goals.png

# Profile
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=profile
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/reg-profile.png

# Onboarding
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --force-onboarding
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/reg-onboarding.png
```

## 4) Chat flow regression

### 4.1 Open chat

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=home --open-chat
sleep 2
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/flow-chat-open.png
```

### 4.2 Quick reply + handoff timing

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=home --open-chat --regression-chat
sleep 5
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/flow-quickreply-final.png
```

### 4.3 Crisis flow

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl terminate booted com.coachingapp.ios || true
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl launch booted com.coachingapp.ios --args --open-tab=home --open-chat --regression-chat --regression-crisis
sleep 5
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun simctl io booted screenshot ~/.openclaw/workspace/artifacts/flow-crisis-final.png
```

## Acceptance checklist

- [ ] Home is not stuck on infinite loading
- [ ] Sessions page renders and Start Session CTA visible
- [ ] Goals list renders with progress bars
- [ ] Profile settings rows render correctly
- [ ] Onboarding shows Continue + Skip
- [ ] Chat opens from Home
- [ ] Sending text creates user + assistant messages
- [ ] Quick replies are fully visible (no clipping)
- [ ] Crisis message opens Crisis Support bottom sheet (not overlapping chat)
- [ ] Human-coach request appears after streaming completes

## Notes

- Regression launch args are debug helpers and safe for simulator-only test runs.
- If backend path/env changes, update `scripts/start_backend.sh` and this file together.
