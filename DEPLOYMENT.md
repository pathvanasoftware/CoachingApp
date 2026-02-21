# Production Deployment Guide

## Railway Deployment (Recommended)

### Prerequisites
- Railway account (https://railway.app)
- GitHub repository connected
- OpenAI API key

### Step 1: Create Railway Project
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login to Railway
railway login

# Initialize project (from CoachingApp root)
railway init
```

### Step 2: Configure Environment Variables
In Railway dashboard, add these variables:
- `OPENAI_API_KEY` = `sk-proj-your-actual-key`
- `REQUIRE_OPENAI_KEY` = `1` (optional, defaults to 1)

### Step 3: Deploy
```bash
# Deploy to Railway
railway up

# Or connect GitHub for auto-deploy:
# 1. Go to Railway Dashboard
# 2. Create New Project → Deploy from GitHub repo
# 3. Select CoachingApp repository
# 4. Railway auto-detects Procfile
```

### Step 4: Verify Deployment
```bash
# Get your Railway URL
railway domain

# Test health endpoint
curl https://your-app.railway.app/

# Expected response:
# {"status":"ok","service":"CoachingApp API"}
```

### Step 5: Configure Custom Domain (Optional)
1. Go to Railway Dashboard → Settings → Domains
2. Add custom domain (e.g., `api.coachingapp.com`)
3. Configure DNS CNAME record

---

## Alternative: Render Deployment

### Step 1: Create Render Account
- Go to https://render.com
- Connect GitHub account

### Step 2: Create Web Service
1. New → Web Service
2. Connect GitHub repository
3. Configure:
   - **Name:** coachingapp-api
   - **Environment:** Python 3
   - **Build Command:** `cd backend && pip install -r requirements.txt`
   - **Start Command:** `cd backend && uvicorn main:app --host 0.0.0.0 --port $PORT`
   - **Instance Type:** Starter (free) or Standard ($7/month)

### Step 3: Add Environment Variables
- `OPENAI_API_KEY` = `sk-proj-your-actual-key`
- `REQUIRE_OPENAI_KEY` = `1`

### Step 4: Deploy
- Click "Create Web Service"
- Render auto-deploys on every push to main

---

## Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENAI_API_KEY` | ✅ Yes | OpenAI API key for GPT-4 |
| `REQUIRE_OPENAI_KEY` | No | Strict mode (default: 1) |
| `PORT` | Auto | Server port (set by platform) |
| `HOST` | Auto | Server host (default: 0.0.0.0) |

---

## Post-Deployment Checklist

- [ ] Health endpoint returns `{"status":"ok"}`
- [ ] Test chat endpoint with curl:
  ```bash
  curl -X POST https://your-domain.com/api/chat/ \
    -H "Content-Type: application/json" \
    -d '{"message":"Hello","user_id":"test"}'
  ```
- [ ] Verify response has style/emotion/goal metadata
- [ ] Test crisis detection with "I want to kill myself" → should return crisis resources
- [ ] Check logs for errors
- [ ] Configure custom domain (optional)
- [ ] Set up monitoring (optional)

---

## Monitoring (Optional)

### Railway Metrics
- Built-in metrics dashboard
- View in Railway Dashboard → Metrics tab

### External Monitoring
- **Uptime Robot:** Free, monitors endpoint every 5 min
- **Better Uptime:** Free tier with incident alerts

### Log Aggregation
- Railway: View logs in Dashboard → Deployments
- Or integrate: Datadog, LogDNA, etc.

---

## Troubleshooting

### "OPENAI_API_KEY is required" error
- Verify environment variable is set in Railway/Render
- Check key format: `sk-proj-...`

### "Module not found" error
- Ensure `backend/requirements.txt` is complete
- Rebuild: Railway → Redeploy

### High latency (>5s)
- Normal for first request (cold start)
- Consider upgrading to paid tier
- Add caching layer (optional)

### CORS errors
- `main.py` already allows all origins
- If issues persist, check client domain configuration

---

## Cost Estimates

### Railway
- **Hobby:** $5/month (512MB RAM, shared CPU)
- **Pro:** $20/month (8GB RAM, 8 vCPU)

### Render
- **Free:** 750 hours/month (spins down when idle)
- **Starter:** $7/month (no spin down)
- **Standard:** $25/month (1GB RAM, 0.5 CPU)

---

## Next Steps After Deployment

1. **Update iOS App Configuration**
   - Change API base URL to production domain
   - Test end-to-end flow

2. **Set Up CI/CD**
   - Already have GitHub Actions for tests
   - Add auto-deploy on main branch push

3. **Add Monitoring**
   - Uptime monitoring
   - Error tracking
   - Performance metrics

4. **Document API**
   - Add OpenAPI/Swagger docs
   - Create API reference for integrators
