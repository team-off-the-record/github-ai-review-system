#!/bin/bash
# Organization 레벨 웹훅 자동 설정

set -e

ORGANIZATION=$1
WEBHOOK_URL="https://webhook.yeonsik.kim/webhook"
WEBHOOK_SECRET=$2

# 사용법 체크
if [ -z "$ORGANIZATION" ] || [ -z "$WEBHOOK_SECRET" ]; then
    echo "Usage: $0 <organization-name> <webhook-secret>"
    echo "Example: $0 myorg mysecretkey123"
    echo ""
    echo "환경변수에서 값을 가져오려면:"
    echo "$0 \$ORGANIZATION_NAME \$GITHUB_WEBHOOK_SECRET"
    exit 1
fi

echo "🚀 Setting up Organization webhook for: $ORGANIZATION"
echo "📡 Webhook URL: $WEBHOOK_URL"

# GitHub CLI 인증 상태 확인
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Please run 'gh auth login' first."
    exit 1
fi

echo "✅ GitHub CLI authenticated"

# Organization 존재 및 권한 확인
echo "🔍 Checking organization access..."
if ! gh api orgs/$ORGANIZATION > /dev/null 2>&1; then
    echo "❌ Cannot access organization '$ORGANIZATION'. Check organization name and permissions."
    echo "   Make sure you are a member of the organization with appropriate permissions."
    exit 1
fi

echo "✅ Organization access confirmed"

# 기존 웹훅 확인 및 처리
echo "🔍 Checking for existing webhooks..."
EXISTING_WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks --jq '.[].config.url' 2>/dev/null || echo "")

if echo "$EXISTING_WEBHOOKS" | grep -q "$WEBHOOK_URL"; then
    echo "⚠️  Webhook already exists for this URL"
    HOOK_ID=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id')
    echo "🗑️  Deleting existing webhook (ID: $HOOK_ID)..."
    gh api orgs/$ORGANIZATION/hooks/$HOOK_ID --method DELETE
    echo "✅ Existing webhook deleted"
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
  ]' 2>&1)

HOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r '.id')

if [ "$HOOK_ID" != "null" ] && [ -n "$HOOK_ID" ] && [ "$HOOK_ID" != "" ]; then
    echo "✅ Organization webhook created successfully!"
    echo "   Hook ID: $HOOK_ID"
    echo "   URL: $WEBHOOK_URL"
    echo "   Events: pull_request, issue_comment, pull_request_review"
    echo ""
    echo "🔧 This webhook will receive events from ALL repositories in the organization."
else
    echo "❌ Failed to create webhook."
    echo "🔍 Debug information:"
    echo "   Organization: $ORGANIZATION"
    echo "   Webhook URL: $WEBHOOK_URL"
    echo "   Response: $WEBHOOK_RESPONSE"
    echo ""
    
    # 일반적인 오류 원인 분석
    if echo "$WEBHOOK_RESPONSE" | grep -q "Not Found"; then
        echo "💡 가능한 원인: Organization을 찾을 수 없음"
        echo "   - Organization 이름을 확인하세요: $ORGANIZATION"
        echo "   - GitHub CLI로 Organization 접근 권한을 확인하세요"
    elif echo "$WEBHOOK_RESPONSE" | grep -q "Forbidden\|permission"; then
        echo "💡 가능한 원인: 권한 부족"
        echo "   - GitHub Token에 admin:org, admin:org_hook 권한이 필요합니다"
        echo "   - Organization의 owner 또는 적절한 권한이 있는지 확인하세요"
    elif echo "$WEBHOOK_RESPONSE" | grep -q "Validation Failed"; then
        echo "💡 가능한 원인: 웹훅 URL 검증 실패"
        echo "   - Webhook URL이 유효하고 접근 가능한지 확인하세요: $WEBHOOK_URL"
    else
        echo "💡 GitHub CLI 인증 상태를 확인하세요: gh auth status"
    fi
    
    exit 1
fi

# 웹훅 연결 테스트
echo "🧪 Testing webhook connectivity..."
if curl -s --max-time 10 "$WEBHOOK_URL" > /dev/null 2>&1; then
    echo "✅ Webhook endpoint is reachable"
elif curl -s --max-time 10 "https://webhook.yeonsik.com" > /dev/null 2>&1; then
    echo "✅ Base domain is reachable"
    echo "⚠️  Note: /webhook endpoint may not be implemented yet"
else
    echo "⚠️  Warning: Webhook endpoint test failed"
    echo "   Make sure Cloudflare Tunnel is running and configured properly"
fi

echo "🎉 Organization webhook setup completed!"
echo ""
echo "📋 Next steps:"
echo "1. Set up the webhook server to handle incoming events"
echo "2. Test with a sample PR in any repository within the organization"
echo "3. Monitor webhook deliveries at: https://github.com/orgs/$ORGANIZATION/settings/hooks"