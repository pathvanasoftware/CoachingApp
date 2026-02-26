# LLM Migration Guide: GPT-4 → Claude Dual-Model

## Overview

This guide covers migrating from OpenAI GPT-4 to the Claude dual-model architecture (Sonnet 4.6 + Opus 4.6).

---

## Why Migrate?

### Cost Savings
- **GPT-4:** $30/1M input tokens, $60/1M output tokens
- **Claude Sonnet 4.6:** $3/1M input tokens, $15/1M output tokens
- **Savings:** 90% cheaper for same quality

### Quality Improvements
- **Better coaching style:** Claude's natural Socratic questioning
- **Longer context:** 200K context window (vs 128K GPT-4)
- **More empathetic tone:** Warm, supportive coaching voice

### Dual-Model Benefits
- **90% conversations:** Sonnet (fast, cost-efficient)
- **10% complex:** Opus (deep reasoning, strategic thinking)
- **72% cost savings** vs all-Opus

---

## Migration Steps

### Step 1: Install Anthropic SDK (5 min)

```bash
cd backend
source venv/bin/activate
pip install anthropic
```

Update `requirements.txt`:
```txt
anthropic>=0.39.0
```

---

### Step 2: Set Environment Variables (2 min)

```bash
# .env
ANTHROPIC_API_KEY=sk-ant-api03-...

# Remove or comment out OpenAI key (optional)
# OPENAI_API_KEY=sk-proj-...
```

**Get API key:** https://console.anthropic.com/

---

### Step 3: Update LLM Service (10 min)

**Option A: Replace entirely (recommended)**

```python
# backend/app/services/llm.py

# OLD
from openai import AsyncOpenAI
client = AsyncOpenAI(api_key=os.getenv("OPENAI_API_KEY"))
response = await client.chat.completions.create(
    model="gpt-4",
    messages=messages,
)

# NEW
from anthropic import AsyncAnthropic
client = AsyncAnthropic(api_key=os.getenv("ANTHROPIC_API_KEY"))
response = await client.messages.create(
    model="claude-sonnet-4-6-20250514",
    system=system_prompt,
    messages=messages,
    max_tokens=800,
)
```

**Option B: Use new file (safer)**

```python
# backend/app/routers/chat.py

# OLD
from app.services.llm import get_coaching_response

# NEW
from app.services.llm_claude import get_coaching_response
```

---

### Step 4: Update API Calls (5 min)

**Key differences:**

| Aspect | OpenAI | Anthropic |
|--------|--------|-----------|
| **System prompt** | In messages array | Separate `system` param |
| **Max tokens** | Optional | **Required** |
| **Model ID** | `"gpt-4"` | `"claude-sonnet-4-6-20250514"` |
| **Response** | `response.choices[0].message.content` | `response.content[0].text` |

**Example:**

```python
# OpenAI format
response = await openai_client.chat.completions.create(
    model="gpt-4",
    messages=[
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": user_message},
    ],
)

# Anthropic format
response = await anthropic_client.messages.create(
    model="claude-sonnet-4-6-20250514",
    system=system_prompt,  # Separate parameter
    messages=[
        {"role": "user", "content": user_message},
    ],
    max_tokens=800,  # Required
)
```

---

### Step 5: Test Thoroughly (15 min)

```bash
# Start backend
cd backend
source venv/bin/activate
export ANTHROPIC_API_KEY="sk-ant-..."
uvicorn main:app --host 0.0.0.0 --port 8000

# Test chat endpoint
curl -X POST http://localhost:8000/api/v1/chat \
  -H "Content-Type: application/json" \
  -d '{
    "message": "I am feeling overwhelmed with my new manager role",
    "user_id": "test_user",
    "history": []
  }'

# Expected response:
# {
#   "response": "...",
#   "quick_replies": [...],
#   "model_used": "claude-sonnet-4-6-20250514",
#   ...
# }
```

---

### Step 6: Update iOS (Optional - 5 min)

No changes needed if API contract remains same.

If you want to display model used:

```swift
// CoachingApp/Models/Message.swift

struct CoachingResponse: Codable {
    let response: String
    let quickReplies: [String]
    let modelUsed: String?  // Add this
    let upgradeReasons: [String]?  // Add this
    // ...
}
```

---

## Testing Checklist

### Functional Tests

- [ ] Basic chat works
- [ ] Multi-turn conversations maintain context
- [ ] Quick replies generated
- [ ] Session summaries work
- [ ] Crisis detection triggers properly
- [ ] Style routing works

### Model Selection Tests

- [ ] Normal conversation → Sonnet 4.6
- [ ] Long conversation (>40 turns) → Opus 4.6
- [ ] Complex decision keywords → Opus 4.6
- [ ] Deep reflection keywords → Opus 4.6
- [ ] Strategic planning keywords → Opus 4.6

### Quality Tests

- [ ] Coaching style is natural
- [ ] Responses are empathetic
- [ ] Socratic questions work well
- [ ] Action items are concrete
- [ ] Tone is professional yet warm

---

## Rollback Plan

If issues arise, rollback is simple:

```bash
# 1. Revert environment variable
export OPENAI_API_KEY="sk-proj-..."
unset ANTHROPIC_API_KEY

# 2. Update import
# backend/app/routers/chat.py
from app.services.llm import get_coaching_response  # OLD

# 3. Restart backend
uvicorn main:app --host 0.0.0.0 --port 8000
```

---

## Cost Monitoring

### Track Usage

```python
# Add to response logging
import logging

logger.info(f"Model used: {model}, Upgrade reasons: {upgrade_reasons}")
```

### Estimate Costs

```python
# After each API call
input_tokens = response.usage.input_tokens
output_tokens = response.usage.output_tokens

if model == CLAUDE_SONNET_4_6:
    cost = (input_tokens * 3/1_000_000) + (output_tokens * 15/1_000_000)
else:  # Opus
    cost = (input_tokens * 15/1_000_000) + (output_tokens * 75/1_000_000)

logger.info(f"Request cost: ${cost:.4f}")
```

---

## FAQ

### Q: Will coaching quality change?
**A:** Yes - it will improve. Claude is specifically better at:
- Natural Socratic questioning
- Maintaining long conversation context
- Warm, empathetic tone

### Q: What if Claude is down?
**A:** Anthropic has 99.9% uptime SLA. You can also implement fallback:
```python
try:
    response = await anthropic_client.messages.create(...)
except anthropic.APIError:
    # Fallback to OpenAI
    response = await openai_client.chat.completions.create(...)
```

### Q: How do I know when Opus is used?
**A:** Check `model_used` and `upgrade_reasons` in response:
```json
{
  "model_used": "claude-opus-4-6-20250514",
  "upgrade_reasons": ["complex_decision", "long_context"]
}
```

### Q: Can I force use of Opus?
**A:** Yes, add `force_model` parameter:
```python
response = await get_coaching_response(
    message="...",
    force_model="opus"  # Force Opus 4.6
)
```

---

## Timeline

| Step | Time | Owner |
|------|------|-------|
| Install SDK | 5 min | Backend |
| Set env vars | 2 min | Backend |
| Update LLM service | 10 min | Backend |
| Test locally | 15 min | Backend |
| Deploy to staging | 5 min | DevOps |
| Test staging | 10 min | QA |
| Deploy to production | 5 min | DevOps |
| Monitor | Ongoing | All |

**Total time:** ~1 hour

---

## Success Metrics

After migration, track:

- [ ] **Cost reduction:** Should see 80-90% drop in LLM costs
- [ ] **Response quality:** User satisfaction should increase
- [ ] **Latency:** Should be similar or slightly faster
- [ ] **Error rate:** Should remain low (<1%)

---

## Support

- **Anthropic docs:** https://docs.anthropic.com/
- **Model comparison:** https://www.anthropic.com/claude
- **Discord support:** #coaching channel

---

**Migration complete!** 🎉

You're now running on Claude dual-model architecture with 90% cost savings and better coaching quality.
