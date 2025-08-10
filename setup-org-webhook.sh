#!/bin/bash
# Organization 레벨 웹훅 자동 설정

set -e

ORGANIZATION=$1
WEBHOOK_URL="https://webhook.yeonsik.com/webhook"
WEBHOOK_SECRET=$2

# 사용법 체크
if [ -z "$ORGANIZATION" ] || [ -z "$WEBHOOK_SECRET" ]; then
    echo "Usage: $0 <organization-name> <webhook-secret>"
    echo "Example: $0 myorg mysecretkey123"
    exit 1
fi

echo "🚀 Setting up Organization webhook for: $ORGANIZATION"
echo "📡 Webhook URL: $WEBHOOK_URL"

# GitHub CLI 인증 상태 확인
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Please run 'gh auth login' first."
    exit 1
fi

# Organization 존재 및 권한 확인
if ! gh api orgs/$ORGANIZATION > /dev/null 2>&1; then
    echo "❌ Cannot access organization '$ORGANIZATION'. Check organization name and permissions."
    exit 1
fi

echo "✅ Organization access confirmed"

# 기존 웹훅 확인 및 처리
echo "🔍 Checking for existing webhooks..."
EXISTING_WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks --jq '.[].config.url' 2>/dev/null || echo "")

if echo "$EXISTING_WEBHOOKS" | grep -q "$WEBHOOK_URL"; then
    echo "⚠️  Webhook already exists for this URL"
    HOOK_ID=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id')
    gh api orgs/$ORGANIZATION/hooks/$HOOK_ID --method DELETE
    echo "🗑️  Existing webhook deleted"
fi

# 새 웹훅 생성
echo "📝 Creating organization webhook..."

WEBHOOK_RESPONSE=$(gh api orgs/$ORGANIZATION/hooks \
  --method POST \
  --field name=web \
  --field active=true \
  --raw-field config='{
    "url": "'$WEBHOOK_URL'",
    "content_type": "json",
    "secret": "'$WEBHOOK_SECRET'",
    "insecure_ssl": "0"
  }' \
  --raw-field events='[
    "pull_request",
    "issue_comment",
    "pull_request_review"
  ]' 2>/dev/null)

HOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r '.id')

if [ "$HOOK_ID" != "null" ] && [ -n "$HOOK_ID" ]; then
    echo "✅ Organization webhook created successfully!"
    echo "   Hook ID: $HOOK_ID"
    echo "   URL: $WEBHOOK_URL"
    echo "   Events: pull_request, issue_comment, pull_request_review"
    echo ""
    echo "🔧 This webhook will receive events from ALL repositories in the organization."
else
    echo "❌ Failed to create webhook."
    exit 1
fi

# 웹훅 연결 테스트
echo "🧪 Testing webhook connectivity..."
if curl -s --max-time 10 "$WEBHOOK_URL/health" > /dev/null 2>&1; then
    echo "✅ Webhook endpoint is reachable"
else
    echo "⚠️  Warning: Webhook endpoint test failed"
    echo "   Make sure Cloudflare Tunnel is running: systemctl status cloudflared-tunnel"
fi

echo "🎉 Organization webhook setup completed!"