#!/bin/bash
# Organization 설정 확인 스크립트

if [ -z "$ORGANIZATION_NAME" ]; then
    echo "ORGANIZATION_NAME 환경변수가 설정되지 않았습니다."
    exit 1
fi

echo "🔍 Organization 설정 상세 확인"
echo "============================="
echo "Organization: $ORGANIZATION_NAME"
echo ""

# 1. Organization 기본 정보
echo "1️⃣ Organization 기본 정보:"
gh api orgs/$ORGANIZATION_NAME --jq '{
  login: .login,
  name: .name,
  type: .type,
  public_repos: .public_repos,
  private_repos: .private_repos,
  plan: .plan.name
}'

echo ""

# 2. Organization 권한 및 설정 확인
echo "2️⃣ Organization 권한 설정:"
ORG_SETTINGS=$(gh api orgs/$ORGANIZATION_NAME --jq '{
  has_organization_projects: .has_organization_projects,
  has_repository_projects: .has_repository_projects,
  hooks_url: .hooks_url,
  members_url: .members_url
}')
echo "$ORG_SETTINGS"

echo ""

# 3. 현재 사용자의 Organization 멤버십 상세
echo "3️⃣ 사용자 멤버십 상세:"
CURRENT_USER=$(gh api user --jq '.login')
MEMBERSHIP=$(gh api orgs/$ORGANIZATION_NAME/memberships/$CURRENT_USER 2>&1)

if echo "$MEMBERSHIP" | grep -q "Not Found\|404"; then
    echo "❌ 멤버십 정보 조회 실패"
    echo "응답: $MEMBERSHIP"
else
    echo "$MEMBERSHIP" | jq '{
      role: .role,
      state: .state,
      url: .url
    }' 2>/dev/null || echo "$MEMBERSHIP"
fi

echo ""

# 4. Organization의 웹훅 관련 URL 직접 확인
echo "4️⃣ 웹훅 API 엔드포인트 직접 테스트:"
HOOKS_URL="https://api.github.com/orgs/$ORGANIZATION_NAME/hooks"
echo "API URL: $HOOKS_URL"

# GitHub CLI 대신 curl로 직접 테스트
echo "Direct API 테스트 결과:"
CURL_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
  -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  "$HOOKS_URL" 2>&1)

HTTP_STATUS=$(echo "$CURL_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$CURL_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

echo "HTTP Status: $HTTP_STATUS"
if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ Organization 웹훅 API 접근 성공"
    HOOK_COUNT=$(echo "$RESPONSE_BODY" | jq '. | length' 2>/dev/null || echo "파싱 실패")
    echo "현재 웹훅 개수: $HOOK_COUNT"
elif [ "$HTTP_STATUS" = "404" ]; then
    echo "❌ 404 Not Found - Organization 웹훅 기능이 비활성화되었거나 접근 권한 없음"
    echo "Response: $RESPONSE_BODY"
elif [ "$HTTP_STATUS" = "403" ]; then
    echo "❌ 403 Forbidden - 권한 부족"
    echo "Response: $RESPONSE_BODY"
else
    echo "❌ 예상치 못한 응답 ($HTTP_STATUS)"
    echo "Response: $RESPONSE_BODY"
fi

echo ""

# 5. Organization Plan 확인 (일부 plan에서는 웹훅 제한이 있을 수 있음)
echo "5️⃣ Organization Plan 확인:"
PLAN_INFO=$(gh api orgs/$ORGANIZATION_NAME --jq '{
  plan_name: .plan.name,
  plan_space: .plan.space,
  plan_private_repos: .plan.private_repos
}' 2>/dev/null)
echo "$PLAN_INFO"

# Free plan인 경우 경고
if echo "$PLAN_INFO" | grep -q '"plan_name":"free"'; then
    echo "⚠️ Free plan Organization - 일부 기능에 제한이 있을 수 있습니다"
fi

echo ""
echo "🎯 문제 해결 제안:"
echo "1. HTTP Status가 404인 경우:"
echo "   - Organization 설정에서 Third-party application access policy 확인"
echo "   - Organization → Settings → Third-party access 확인"
echo ""
echo "2. 권한 문제인 경우:"
echo "   - GitHub Token의 admin:org 권한 재확인"
echo "   - Organization owner에게 웹훅 설정 권한 요청"
echo ""
echo "3. 대안으로 Repository별 웹훅 사용 고려"