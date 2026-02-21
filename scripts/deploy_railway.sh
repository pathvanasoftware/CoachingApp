#!/usr/bin/env bash
set -euo pipefail

echo "🚀 CoachingApp Production Deployment"
echo "====================================="
echo ""

# Check if Railway CLI is installed
if ! command -v railway &> /dev/null; then
    echo "❌ Railway CLI not found."
    echo ""
    echo "Install it with:"
    echo "  npm install -g @railway/cli"
    echo ""
    echo "Then run this script again."
    exit 1
fi

# Check if logged in
if ! railway whoami &> /dev/null; then
    echo "⚠️  Not logged in to Railway."
    echo ""
    echo "Please login first:"
    echo "  railway login"
    exit 1
fi

# Check for OPENAI_API_KEY
if [ -z "${OPENAI_API_KEY:-}" ]; then
    echo "⚠️  OPENAI_API_KEY not found in environment."
    echo ""
    echo "Please set it first:"
    echo "  export OPENAI_API_KEY='sk-proj-your-key'"
    exit 1
fi

echo "✅ Prerequisites checked"
echo ""

# Initialize project if needed
if [ ! -f ".railway.json" ] && [ ! -f "railway.json" ]; then
    echo "📝 Initializing Railway project..."
    railway init || true
fi

echo ""
echo "🔧 Setting environment variables..."
railway variables set OPENAI_API_KEY="$OPENAI_API_KEY"
railway variables set REQUIRE_OPENAI_KEY="1"

echo ""
echo "🚀 Deploying to Railway..."
railway up

echo ""
echo "✅ Deployment complete!"
echo ""
echo "Next steps:"
echo "1. Get your domain:"
echo "   railway domain"
echo ""
echo "2. Test the API:"
echo "   curl https://your-domain.railway.app/"
echo ""
echo "3. View logs:"
echo "   railway logs"
echo ""
