# CoachingApp

**AI-Powered Career & Executive Coaching Platform**

An intelligent coaching application that uses GPT-4 to provide personalized career and leadership development guidance.

---

## Features

✅ **4 Coaching Styles** - Directive, Facilitative, Supportive, Strategic (auto-routed)
✅ **Emotional Intelligence** - Multi-signal emotion detection with sentiment analysis
✅ **Goal-Oriented Architecture** - Strategic/Tactical/Daily hierarchy with anchoring
✅ **Crisis Detection** - Automatic escalation with professional resources
✅ **Persistent Memory** - User profiles with emotion timeline and behavior signals
✅ **Streaming Metadata** - Real-time style/emotion/goal feedback
✅ **Quick Replies** - Contextual response chips after each turn

---

## Quick Start

### Prerequisites
- Python 3.11+
- OpenAI API key
- Xcode 15+ (for iOS app)

### Local Development

1. **Start Backend**
   ```bash
   export OPENAI_API_KEY='sk-proj-your-key'
   ./scripts/start_backend.sh
   ```

2. **Verify API**
   ```bash
   curl http://localhost:8000/
   # {"status":"ok","service":"CoachingApp API"}
   ```

3. **Run iOS App**
   - Open `CoachingApp.xcodeproj` in Xcode
   - Select target device
   - Build & Run (⌘R)

### API Base URL
- **Local:** `http://localhost:8000/api/v1`
- **Production:** `https://your-domain.com/api/v1`

---

## Coaching Styles

The API auto-selects style based on message content + emotion:
- **Directive** - Specific advice and clear direction
- **Facilitative** - Guided exploration with questions
- **Supportive** - Emotional support and encouragement
- **Strategic** - Long-term planning and frameworks

Override with `coaching_style` parameter:
```json
{
  "message": "I need help with...",
  "user_id": "user123",
  "coaching_style": "strategic"
}
```

---

## Production Deployment

See [DEPLOYMENT.md](./DEPLOYMENT.md) for detailed instructions.

### Quick Deploy to Railway
```bash
# Install Railway CLI
npm install -g @railway/cli

# Set API key and deploy
export OPENAI_API_KEY='sk-proj-your-key'
./scripts/deploy_railway.sh
```

---

## Documentation

- [DEPLOYMENT.md](./DEPLOYMENT.md) - Production deployment guide
- [PILOT_READINESS.md](./PILOT_READINESS.md) - Validation test results
- [dialogue_test_20260221_014719.md](./dialogue_test_20260221_014719.md) - Example dialogues

---

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/` | GET | Health check |
| `/api/chat/` | POST | Main coaching chat |
| `/api/v1/chat-stream` | POST | SSE streaming (iOS) |
| `/api/debug/profile/{user_id}` | GET | User memory profile |

### Example Request
```bash
curl -X POST http://localhost:8000/api/chat/ \
  -H "Content-Type: application/json" \
  -d '{
    "message": "I want to get promoted to Director",
    "user_id": "user123"
  }'
```

### Response Format
```json
{
  "response": "Coaching response text...",
  "quick_replies": ["Option 1", "Option 2", "Option 3"],
  "style_used": "strategic",
  "emotion_primary": "neutral",
  "goal_link": "career_advancement",
  "goal_anchor": "...",
  "outcome_prediction": {...}
}
```

---

## Tech Stack

- **Backend:** FastAPI, Python 3.11, OpenAI GPT-4
- **iOS:** SwiftUI, iOS 17+
- **Architecture:** Goal-Oriented Dialogue + Emotional Intelligence Engine
- **Memory:** File-based user profiles with behavior tracking
- **CI/CD:** GitHub Actions (tests + pilot smoke)

---

## Testing

### Backend Tests
```bash
cd backend
pytest --cov=app --cov-fail-under=80
```

Current coverage: **88.87%**

---

## License

MIT

---

## Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Run tests before submitting PR
4. Update documentation as needed
