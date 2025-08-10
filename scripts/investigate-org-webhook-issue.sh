#!/bin/bash
# Organization 웹훅 404 오류 상세 조사 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

if [ -z "$ORGANIZATION_NAME" ] || [ -z "$GITHUB_WEBHOOK_TOKEN" ]; then
    printf "${RED}❌ ORGANIZATION_NAME과 GITHUB_WEBHOOK_TOKEN 환경변수가 필요합니다.${NC}\n"
    exit 1
fi

printf "${CYAN}🔍 Organization 웹훅 404 오류 상세 조사${NC}\n"
printf "Organization: ${YELLOW}$ORGANIZATION_NAME${NC}\n"
echo ""

# 1. GitHub CLI 및 토큰 권한 확인
printf "${BLUE}1️⃣ GitHub CLI 및 토큰 권한 확인${NC}\n"
echo "=================================="

# 현재 사용자 정보
CURRENT_USER=$(gh api user --jq '.login' 2>/dev/null || echo "unknown")
printf "Current User: ${GREEN}$CURRENT_USER${NC}\n"

# 토큰 스코프 확인 (GitHub API를 통해)
printf "\n토큰 스코프 확인:\n"
TOKEN_SCOPES=$(curl -s -I -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" https://api.github.com/user | grep -i "x-oauth-scopes" | cut -d: -f2 | tr -d ' ')
printf "Token Scopes: ${CYAN}$TOKEN_SCOPES${NC}\n"

# 필요한 스코프들 확인
REQUIRED_SCOPES="admin:org admin:org_hook repo"

printf "\n필요한 스코프 확인:\n"
for scope in $REQUIRED_SCOPES; do
    if echo "$TOKEN_SCOPES" | grep -q "$scope"; then
        printf "${GREEN}✅ $scope 스코프 확인됨${NC}\n"
    else
        printf "${RED}❌ $scope 스코프 누락${NC}\n"
    fi
done

echo ""

# 2. Organization 멤버십 및 권한 상세 확인
printf "${BLUE}2️⃣ Organization 멤버십 및 권한 상세 확인${NC}\n"
echo "============================================="

# Organization 기본 정보
ORG_INFO=$(gh api orgs/$ORGANIZATION_NAME 2>/dev/null || echo "{}")
if [ "$ORG_INFO" = "{}" ]; then
    printf "${RED}❌ Organization 정보를 가져올 수 없습니다.${NC}\n"
else
    PLAN_NAME=$(echo "$ORG_INFO" | jq -r '.plan.name // "unknown"')
    ORG_TYPE=$(echo "$ORG_INFO" | jq -r '.type // "unknown"')
    printf "Plan: ${CYAN}$PLAN_NAME${NC}\n"
    printf "Type: ${CYAN}$ORG_TYPE${NC}\n"
fi

# 멤버십 확인
printf "\n멤버십 확인:\n"
MEMBERSHIP_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
    -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORGANIZATION_NAME/memberships/$CURRENT_USER")

MEMBERSHIP_STATUS=$(echo "$MEMBERSHIP_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
MEMBERSHIP_BODY=$(echo "$MEMBERSHIP_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

if [ "$MEMBERSHIP_STATUS" = "200" ]; then
    ROLE=$(echo "$MEMBERSHIP_BODY" | jq -r '.role // "unknown"')
    STATE=$(echo "$MEMBERSHIP_BODY" | jq -r '.state // "unknown"')
    printf "${GREEN}✅ 멤버십 확인됨${NC}\n"
    printf "Role: ${CYAN}$ROLE${NC}\n"
    printf "State: ${CYAN}$STATE${NC}\n"
    
    if [ "$ROLE" = "admin" ]; then
        printf "${GREEN}✅ Organization Admin 권한 확인${NC}\n"
    else
        printf "${YELLOW}⚠️ Organization Admin 권한 없음 (현재: $ROLE)${NC}\n"
    fi
else
    printf "${RED}❌ 멤버십 확인 실패 (HTTP: $MEMBERSHIP_STATUS)${NC}\n"
    printf "Response: $MEMBERSHIP_BODY\n"
fi

echo ""

# 3. Organization 설정 확인
printf "${BLUE}3️⃣ Organization 설정 확인${NC}\n"
echo "============================="

# Third-party access policy 확인
printf "Third-party Application Access Policy 확인:\n"
THIRD_PARTY_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
    -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORGANIZATION_NAME/settings/third_party_access")

THIRD_PARTY_STATUS=$(echo "$THIRD_PARTY_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
THIRD_PARTY_BODY=$(echo "$THIRD_PARTY_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

if [ "$THIRD_PARTY_STATUS" = "200" ]; then
    RESTRICTION_ENABLED=$(echo "$THIRD_PARTY_BODY" | jq -r '.restriction_enabled // false')
    if [ "$RESTRICTION_ENABLED" = "true" ]; then
        printf "${YELLOW}⚠️ Third-party application access restriction이 활성화됨${NC}\n"
        printf "이것이 웹훅 설정을 차단할 수 있습니다.\n"
    else
        printf "${GREEN}✅ Third-party application access restriction 비활성화${NC}\n"
    fi
else
    printf "${YELLOW}⚠️ Third-party access policy 확인 실패 (HTTP: $THIRD_PARTY_STATUS)${NC}\n"
fi

echo ""

# 4. Organization 웹훅 API 직접 테스트
printf "${BLUE}4️⃣ Organization 웹훅 API 직접 테스트${NC}\n"
echo "========================================="

HOOKS_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
    -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORGANIZATION_NAME/hooks")

HOOKS_STATUS=$(echo "$HOOKS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
HOOKS_BODY=$(echo "$HOOKS_RESPONSE" | sed 's/HTTP_STATUS:[0-9]*$//')

printf "API URL: ${CYAN}https://api.github.com/orgs/$ORGANIZATION_NAME/hooks${NC}\n"
printf "HTTP Status: ${CYAN}$HOOKS_STATUS${NC}\n"

case "$HOOKS_STATUS" in
    200)
        printf "${GREEN}✅ Organization 웹훅 API 접근 성공${NC}\n"
        HOOK_COUNT=$(echo "$HOOKS_BODY" | jq '. | length' 2>/dev/null || echo "0")
        printf "현재 웹훅 개수: ${CYAN}$HOOK_COUNT${NC}\n"
        ;;
    404)
        printf "${RED}❌ 404 Not Found - Organization 웹훅 기능 사용 불가${NC}\n"
        printf "가능한 원인:\n"
        echo "  - GitHub Plan 제한 (Free plan에서는 Organization 웹훅 미지원)"
        echo "  - Organization 설정에서 웹훅 기능 비활성화"
        echo "  - Third-party application 제한"
        ;;
    403)
        printf "${RED}❌ 403 Forbidden - 권한 부족${NC}\n"
        printf "Response: $HOOKS_BODY\n"
        ;;
    *)
        printf "${RED}❌ 예상치 못한 응답 ($HOOKS_STATUS)${NC}\n"
        printf "Response: $HOOKS_BODY\n"
        ;;
esac

echo ""

# 5. GitHub Plan별 웹훅 기능 확인
printf "${BLUE}5️⃣ GitHub Plan별 웹훅 기능 분석${NC}\n"
echo "================================="

if [ "$PLAN_NAME" = "free" ]; then
    printf "${RED}❌ Free Plan Organization${NC}\n"
    printf "제한사항:\n"
    echo "  - Organization 레벨 웹훅 미지원"
    echo "  - Repository 레벨 웹훅만 사용 가능"
    echo "  - Public repository 우선 권장"
    printf "\n${YELLOW}💡 해결책: Repository별 웹훅 설정 사용${NC}\n"
elif [ "$PLAN_NAME" = "team" ] || [ "$PLAN_NAME" = "business" ]; then
    printf "${GREEN}✅ Paid Plan ($PLAN_NAME)${NC}\n"
    printf "Organization 웹훅이 지원되어야 함\n"
    printf "${YELLOW}⚠️ 다른 원인 조사 필요${NC}\n"
else
    printf "${YELLOW}⚠️ Plan 정보 불분명 ($PLAN_NAME)${NC}\n"
fi

echo ""

# 6. Repository 웹훅 테스트 (대안 확인)
printf "${BLUE}6️⃣ Repository 웹훅 대안 테스트${NC}\n"
echo "================================"

# 첫 번째 repository 찾기
FIRST_REPO=$(gh api orgs/$ORGANIZATION_NAME/repos --jq '.[0].name' 2>/dev/null || echo "")

if [ -n "$FIRST_REPO" ]; then
    printf "테스트 Repository: ${CYAN}$FIRST_REPO${NC}\n"
    
    REPO_HOOKS_RESPONSE=$(curl -s -w "HTTP_STATUS:%{http_code}" \
        -H "Authorization: token $GITHUB_WEBHOOK_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        "https://api.github.com/repos/$ORGANIZATION_NAME/$FIRST_REPO/hooks")
    
    REPO_HOOKS_STATUS=$(echo "$REPO_HOOKS_RESPONSE" | grep "HTTP_STATUS:" | cut -d: -f2)
    
    if [ "$REPO_HOOKS_STATUS" = "200" ]; then
        printf "${GREEN}✅ Repository 웹훅 API 접근 가능${NC}\n"
        printf "대안: Repository별 웹훅 설정 사용 권장\n"
    else
        printf "${RED}❌ Repository 웹훅도 사용 불가 (HTTP: $REPO_HOOKS_STATUS)${NC}\n"
    fi
else
    printf "${YELLOW}⚠️ 테스트할 Repository를 찾을 수 없음${NC}\n"
fi

echo ""

# 7. 최종 권장사항
printf "${CYAN}🎯 최종 분석 및 권장사항${NC}\n"
echo "========================="

printf "\n${YELLOW}📋 문제 요약:${NC}\n"
echo "Organization 웹훅 API가 404 오류를 반환하고 있습니다."

printf "\n${GREEN}💡 해결책:${NC}\n"

if [ "$PLAN_NAME" = "free" ]; then
    echo "1. ✅ Repository별 웹훅 사용 (권장)"
    echo "   - setup-repo-webhooks.sh 스크립트 사용"
    echo "   - 각 Repository에 개별적으로 웹훅 설정"
    echo ""
    echo "2. Organization Plan 업그레이드 고려"
    echo "   - Team Plan 이상에서 Organization 웹훅 지원"
else
    echo "1. Third-party application 설정 확인"
    echo "   - Organization Settings → Third-party access"
    echo "   - Application restrictions 해제"
    echo ""
    echo "2. Organization Admin 권한 확인"
    echo "   - 현재 권한: $ROLE"
    echo "   - Admin 권한 필요시 Organization Owner에게 요청"
    echo ""
    echo "3. ✅ Repository별 웹훅 사용 (대안)"
    echo "   - setup-repo-webhooks.sh 스크립트 사용"
fi

printf "\n${CYAN}🚀 다음 단계:${NC}\n"
echo "Repository별 웹훅 설정을 진행하세요:"
echo "  cd ~/github-ai-review-system"
echo "  ./scripts/setup-repo-webhooks.sh"