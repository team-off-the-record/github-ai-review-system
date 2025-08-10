#!/bin/bash
# GitHub Organization AI Review System 웹훅 서버 시작 스크립트

set -e

# 스크립트 디렉토리 및 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "🚀 Starting GitHub Organization AI Review System"
echo "================================================"
echo "📁 Project Directory: $PROJECT_ROOT"

# 환경변수 확인
if [ -z "$GITHUB_WEBHOOK_TOKEN" ]; then
    echo "❌ GITHUB_WEBHOOK_TOKEN not set"
    echo "Please run: source ~/.bashrc or set environment variables"
    exit 1
fi

if [ -z "$GITHUB_WEBHOOK_SECRET" ]; then
    echo "❌ GITHUB_WEBHOOK_SECRET not set"
    echo "Please run: source ~/.bashrc or set environment variables"
    exit 1
fi

if [ -z "$ORGANIZATION_NAME" ]; then
    echo "❌ ORGANIZATION_NAME not set"
    echo "Please run: source ~/.bashrc or set environment variables"
    exit 1
fi

echo "✅ Environment variables configured"

# Node.js dependencies 설치
if [ ! -d "node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
fi

# 로그 디렉토리 생성
mkdir -p "$PROJECT_ROOT/logs"
touch "$PROJECT_ROOT/logs/webhook-server.log"

echo "✅ Log file configured: $PROJECT_ROOT/logs/webhook-server.log"

# GitHub CLI 인증 확인
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    echo "Please run: gh auth login"
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Claude Code 확인
if ! command -v claude &> /dev/null; then
    echo "❌ Claude Code not found in PATH"
    echo "Please install Claude Code and ensure it's in your PATH"
    exit 1
fi

echo "✅ Claude Code available"

# SubAgent 확인
echo "🔍 Checking SubAgents..."
AGENTS=("security-reviewer" "architecture-reviewer" "performance-reviewer" "ux-reviewer")
for agent in "${AGENTS[@]}"; do
    if claude --agent "$agent" --help > /dev/null 2>&1; then
        echo "  ✅ $agent"
    else
        echo "  ❌ $agent not found"
        echo "Please ensure all SubAgents are properly installed"
        exit 1
    fi
done

# 웹훅 설정 확인
echo "🔍 Checking webhook configuration..."
if "$SCRIPT_DIR/check-org-webhook.sh" "$ORGANIZATION_NAME" | grep -q "Claude Review webhook found"; then
    echo "✅ Organization webhook configured"
else
    echo "⚠️ Organization webhook not found"
    echo "Run: $SCRIPT_DIR/setup-org-webhook.sh $ORGANIZATION_NAME $GITHUB_WEBHOOK_SECRET"
fi

# 서버 시작
echo ""
echo "🎯 Starting webhook server..."
echo "📝 Logs will be written to $PROJECT_ROOT/logs/webhook-server.log"
echo "🔗 Health check: http://localhost:3000/health"
echo "📊 Status: http://localhost:3000/status"
echo ""
echo "Press Ctrl+C to stop the server"
echo ""

# PM2로 실행하거나 직접 실행
if command -v pm2 &> /dev/null; then
    echo "🔧 Starting with PM2..."
    pm2 start src/webhook-server.js --name "github-ai-review" --watch --log "$PROJECT_ROOT/logs/webhook-server.log"
    pm2 logs github-ai-review --lines 50
else
    echo "🔧 Starting directly..."
    node src/webhook-server.js
fi