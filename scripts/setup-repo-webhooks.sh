#!/bin/bash
# Repository별 웹훅 설정 스크립트 (Organization 웹훅 대안)

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# 환경변수 확인
if [ -z "$ORGANIZATION_NAME" ] || [ -z "$WEBHOOK_SECRET" ] || [ -z "$WEBHOOK_URL" ]; then
    printf "${RED}❌ 필요한 환경변수가 설정되지 않았습니다.${NC}\n"
    echo "필요한 환경변수: ORGANIZATION_NAME, WEBHOOK_SECRET, WEBHOOK_URL"
    exit 1
fi

printf "${CYAN}🔧 Repository별 웹훅 설정 시작${NC}\n"
printf "Organization: ${YELLOW}$ORGANIZATION_NAME${NC}\n"
printf "Webhook URL: ${YELLOW}$WEBHOOK_URL${NC}\n"
echo ""

# Repository 목록 조회 함수
get_org_repositories() {
    local org_name="$1"
    local repos_json
    
    printf "${BLUE}📋 Organization의 Repository 목록 조회 중...${NC}\n"
    
    # Organization의 모든 repository 조회 (private 포함)
    repos_json=$(gh api orgs/$org_name/repos --paginate --jq '.[] | select(.archived == false) | {name: .name, private: .private, default_branch: .default_branch}')
    
    if [ -z "$repos_json" ]; then
        printf "${RED}❌ Repository 목록을 가져올 수 없습니다.${NC}\n"
        return 1
    fi
    
    echo "$repos_json"
}

# Repository에 웹훅 설정 함수
setup_repo_webhook() {
    local repo_name="$1"
    local is_private="$2"
    
    printf "${CYAN}🔗 Setting up webhook for ${repo_name}...${NC}\n"
    
    # 기존 웹훅 확인
    existing_webhooks=$(gh api repos/$ORGANIZATION_NAME/$repo_name/hooks --jq ".[] | select(.config.url == \"$WEBHOOK_URL\") | .id" 2>/dev/null || echo "")
    
    if [ -n "$existing_webhooks" ]; then
        printf "   ${YELLOW}⚠️ 기존 웹훅이 존재합니다. 업데이트합니다.${NC}\n"
        for hook_id in $existing_webhooks; do
            gh api repos/$ORGANIZATION_NAME/$repo_name/hooks/$hook_id -X DELETE
            printf "   ${GREEN}✅ 기존 웹훅 삭제됨 (ID: $hook_id)${NC}\n"
        done
    fi
    
    # 새 웹훅 생성
    webhook_payload=$(cat <<EOF
{
  "config": {
    "url": "$WEBHOOK_URL",
    "content_type": "json",
    "secret": "$WEBHOOK_SECRET",
    "insecure_ssl": "0"
  },
  "events": [
    "pull_request",
    "pull_request_review",
    "pull_request_review_comment",
    "issue_comment",
    "push"
  ],
  "active": true
}
EOF
)
    
    result=$(gh api repos/$ORGANIZATION_NAME/$repo_name/hooks -X POST --input - <<< "$webhook_payload" 2>&1)
    
    if echo "$result" | grep -q '"id":'; then
        webhook_id=$(echo "$result" | jq -r '.id')
        printf "   ${GREEN}✅ 웹훅 생성 성공 (ID: $webhook_id)${NC}\n"
        return 0
    else
        printf "   ${RED}❌ 웹훅 생성 실패${NC}\n"
        echo "   Error: $result"
        return 1
    fi
}

# Repository 선택 함수
select_repositories() {
    local repos_data="$1"
    local selected_repos=""
    
    printf "\n${CYAN}🎯 웹훅을 설정할 Repository 선택${NC}\n"
    echo "======================================"
    echo "1. 모든 Repository"
    echo "2. 특정 Repository 선택"
    echo "3. Public Repository만"
    echo "4. Private Repository만"
    echo ""
    
    while true; do
        printf "선택 (1-4): "
        read -r choice
        
        case $choice in
            1)
                printf "${GREEN}모든 Repository에 웹훅 설정${NC}\n"
                selected_repos=$(echo "$repos_data" | jq -r '.name')
                break
                ;;
            2)
                printf "\n${BLUE}사용 가능한 Repository:${NC}\n"
                echo "$repos_data" | jq -r '. | "\(.name) (\(if .private then "private" else "public" end))"' | nl
                echo ""
                printf "Repository 이름을 입력하세요 (공백으로 구분): "
                read -r manual_selection
                selected_repos="$manual_selection"
                break
                ;;
            3)
                printf "${GREEN}Public Repository만 선택${NC}\n"
                selected_repos=$(echo "$repos_data" | jq -r 'select(.private == false) | .name')
                break
                ;;
            4)
                printf "${GREEN}Private Repository만 선택${NC}\n"
                selected_repos=$(echo "$repos_data" | jq -r 'select(.private == true) | .name')
                break
                ;;
            *)
                printf "${RED}올바른 선택을 입력하세요 (1-4)${NC}\n"
                ;;
        esac
    done
    
    echo "$selected_repos"
}

# 메인 실행부
main() {
    # Repository 목록 조회
    repos_data=$(get_org_repositories "$ORGANIZATION_NAME")
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Repository 개수 확인
    repo_count=$(echo "$repos_data" | wc -l)
    printf "${GREEN}✅ ${repo_count}개의 Repository 발견${NC}\n"
    
    # Repository 선택
    selected_repos=$(select_repositories "$repos_data")
    
    if [ -z "$selected_repos" ]; then
        printf "${RED}❌ 선택된 Repository가 없습니다.${NC}\n"
        exit 1
    fi
    
    printf "\n${CYAN}🚀 웹훅 설정 시작${NC}\n"
    echo "========================="
    
    success_count=0
    failure_count=0
    
    # 각 Repository에 웹훅 설정
    for repo_name in $selected_repos; do
        # Repository 정보 가져오기
        repo_info=$(echo "$repos_data" | jq -r "select(.name == \"$repo_name\")")
        
        if [ -z "$repo_info" ]; then
            printf "${RED}❌ Repository '$repo_name'를 찾을 수 없습니다.${NC}\n"
            ((failure_count++))
            continue
        fi
        
        is_private=$(echo "$repo_info" | jq -r '.private')
        
        if setup_repo_webhook "$repo_name" "$is_private"; then
            ((success_count++))
        else
            ((failure_count++))
        fi
        
        echo ""
    done
    
    # 결과 요약
    printf "\n${CYAN}📊 웹훅 설정 완료${NC}\n"
    echo "===================="
    printf "${GREEN}✅ 성공: ${success_count}개${NC}\n"
    printf "${RED}❌ 실패: ${failure_count}개${NC}\n"
    
    if [ $success_count -gt 0 ]; then
        printf "\n${GREEN}🎉 Repository별 웹훅 설정이 완료되었습니다!${NC}\n"
        printf "${YELLOW}📝 웹훅 서버를 시작하여 이벤트 수신을 확인하세요.${NC}\n"
        
        # 웹훅 테스트 가이드
        printf "\n${CYAN}🧪 테스트 방법:${NC}\n"
        echo "1. 웹훅 서버 시작:"
        echo "   cd ~/github-ai-review-system"
        echo "   npm start"
        echo ""
        echo "2. 테스트 PR 생성:"
        echo "   - 설정된 Repository 중 하나에 PR 생성"
        echo "   - 웹훅 서버 로그에서 이벤트 수신 확인"
    else
        printf "\n${RED}❌ 모든 웹훅 설정이 실패했습니다.${NC}\n"
        echo "GitHub CLI 권한과 Repository 접근 권한을 확인하세요."
    fi
}

# 스크립트 실행
main "$@"