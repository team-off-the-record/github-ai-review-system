#!/bin/bash
# 웹훅 설정 디버깅 스크립트

set -e

if [ -z "$ORGANIZATION_NAME" ] || [ -z "$GITHUB_WEBHOOK_SECRET" ]; then
    echo "❌ 환경변수가 설정되지 않았습니다."
    echo "ORGANIZATION_NAME: ${ORGANIZATION_NAME:-'설정 안됨'}"
    echo "GITHUB_WEBHOOK_SECRET: ${GITHUB_WEBHOOK_SECRET:+설정됨}"
    exit 1
fi

echo "🔍 웹훅 설정 디버깅"
echo "=================="
echo "Organization: $ORGANIZATION_NAME"
echo "Webhook URL: https://webhook.yeonsik.kim/webhook"
echo ""

# 1. GitHub CLI 인증 확인
echo "1️⃣ GitHub CLI 인증 상태:"
gh auth status

echo ""

# 2. Organization 접근 확인
echo "2️⃣ Organization 접근 확인:"
if gh api orgs/$ORGANIZATION_NAME > /dev/null 2>&1; then
    echo "✅ Organization '$ORGANIZATION_NAME' 접근 가능"
    
    # Organization 정보 확인
    ORG_INFO=$(gh api orgs/$ORGANIZATION_NAME --jq '{name: .name, login: .login, type: .type}')
    echo "Organization 정보: $ORG_INFO"
else
    echo "❌ Organization '$ORGANIZATION_NAME' 접근 불가"
    echo "가능한 원인:"
    echo "- Organization 이름 오타"
    echo "- Organization 멤버가 아님"
    echo "- 비공개 Organization에 대한 권한 없음"
    exit 1
fi

echo ""

# 3. 현재 사용자 권한 확인
echo "3️⃣ 사용자 권한 확인:"
USER_ROLE=$(gh api orgs/$ORGANIZATION_NAME/memberships/$(gh api user --jq '.login') --jq '.role' 2>/dev/null || echo "unknown")
echo "현재 사용자 역할: $USER_ROLE"

if [ "$USER_ROLE" != "admin" ]; then
    echo "⚠️ 경고: Organization webhook을 생성하려면 'admin' 권한이 필요합니다"
    echo "현재 권한: $USER_ROLE"
fi

echo ""

# 4. 기존 웹훅 확인
echo "4️⃣ 기존 웹훅 확인:"
EXISTING_HOOKS_RESPONSE=$(gh api orgs/$ORGANIZATION_NAME/hooks 2>&1 || echo "API_ERROR")
if echo "$EXISTING_HOOKS_RESPONSE" | grep -q "Not Found\|404\|admin:org_hook\|API_ERROR"; then
    echo "❌ Organization 웹훅 API 접근 불가"
    if echo "$EXISTING_HOOKS_RESPONSE" | grep -q "admin:org_hook"; then
        echo "원인: 'admin:org_hook' 스코프가 필요합니다"
        echo "해결방법: gh auth refresh -h github.com -s admin:org_hook"
    else
        echo "원인: 404 Not Found 또는 권한 부족"
    fi
    echo "응답: $EXISTING_HOOKS_RESPONSE"
    EXISTING_HOOKS=0
else
    EXISTING_HOOKS=$(echo "$EXISTING_HOOKS_RESPONSE" | jq '. | length' 2>/dev/null || echo "0")
fi
echo "현재 설정된 웹훅 개수: $EXISTING_HOOKS"

if [ "$EXISTING_HOOKS" -gt 0 ]; then
    echo "기존 웹훅 목록:"
    gh api orgs/$ORGANIZATION_NAME/hooks --jq '.[] | "  - ID: \(.id), URL: \(.config.url), Active: \(.active)"' 2>/dev/null || echo "  웹훅 목록 조회 실패"
fi

echo ""

# 5. 웹훅 URL 접근성 테스트
echo "5️⃣ 웹훅 URL 접근성 테스트:"
WEBHOOK_URL="https://webhook.yeonsik.kim/webhook"

CURL_RESPONSE=$(curl -I --max-time 10 "$WEBHOOK_URL" 2>/dev/null | head -1)
if echo "$CURL_RESPONSE" | grep -q "200\|404\|405\|503"; then
    HTTP_CODE=$(echo "$CURL_RESPONSE" | grep -o '[0-9][0-9][0-9]')
    echo "✅ 웹훅 URL 접근 가능: $WEBHOOK_URL (HTTP $HTTP_CODE)"
    if [ "$HTTP_CODE" = "503" ]; then
        echo "ℹ️ 서비스 일시 불가능하지만 서버는 존재함"
    fi
else
    echo "❌ 웹훅 URL 접근 불가: $WEBHOOK_URL"
    echo "⚠️ GitHub에서 웹훅 URL에 접근할 수 없으면 웹훅 생성이 실패할 수 있습니다"
    echo "응답: $CURL_RESPONSE"
fi

echo ""

# 6. 필요한 스코프 및 권한 요약
echo "6️⃣ 필요한 스코프 및 권한 요약:"
echo "Organization 웹훅을 생성하려면:"
echo "1. GitHub CLI에 'admin:org_hook' 스코프 필요"
echo "2. Organization에서 'admin' 역할 필요 (현재: $USER_ROLE)"
echo "3. 웹훅 URL이 GitHub에서 접근 가능해야 함"

if [ "$USER_ROLE" = "admin" ]; then
    echo "✅ Organization 관리자 권한 있음"
else
    echo "❌ Organization 관리자 권한 필요"
fi

# 현재 토큰 스코프 확인
CURRENT_SCOPES=$(gh auth status 2>&1 | grep "Token scopes:" | cut -d"'" -f2)
if echo "$CURRENT_SCOPES" | grep -q "admin:org_hook"; then
    echo "✅ admin:org_hook 스코프 있음"
else
    echo "❌ admin:org_hook 스코프 없음 (현재: $CURRENT_SCOPES)"
    echo "실행 필요: gh auth refresh -h github.com -s admin:org_hook"
fi

echo ""
echo "🎯 다음 단계:"
echo "1. 위의 모든 항목이 ✅ 표시되어야 웹훅 생성이 가능합니다"
echo "2. 권한 문제가 있다면 Organization owner에게 권한 요청"
echo "3. 문제없다면 './scripts/setup-org-webhook.sh \$ORGANIZATION_NAME \$GITHUB_WEBHOOK_SECRET' 실행"