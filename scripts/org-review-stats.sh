#!/bin/bash
# GitHub Organization AI Review System 모니터링 및 통계

# 스크립트 디렉토리 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ORGANIZATION=$1
DAYS=${2:-7}

if [ -z "$ORGANIZATION" ]; then
    echo "Usage: $0 <organization-name> [days]"
    echo "Example: $0 myorg 7"
    echo ""
    echo "환경변수에서 값을 가져오려면:"
    echo "$0 \$ORGANIZATION_NAME 7"
    exit 1
fi

echo "📊 AI Review Statistics for $ORGANIZATION (Last $DAYS days)"
echo "========================================================="
echo ""

# GitHub CLI 인증 확인
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated"
    exit 1
fi

# Organization 존재 확인
if ! gh api orgs/$ORGANIZATION > /dev/null 2>&1; then
    echo "❌ Cannot access organization '$ORGANIZATION'"
    exit 1
fi

echo "🏢 Organization: $ORGANIZATION"
echo "📅 Period: Last $DAYS days"
echo "🕐 Generated: $(date)"
echo ""

# 날짜 계산 (ISO 8601 형식)
SINCE_DATE=$(date -d "$DAYS days ago" -I)

# Organization 저장소 목록
echo "🔍 Fetching repositories..."
REPOS=$(gh api orgs/$ORGANIZATION/repos --paginate --jq '.[].full_name' | head -20)
REPO_COUNT=$(echo "$REPOS" | wc -l)

echo "📁 Found $REPO_COUNT repositories (showing up to 20)"
echo ""

TOTAL_PRS=0
AI_REVIEWED_PRS=0
TOTAL_COMMENTS=0
AI_COMMENTS=0

for repo in $REPOS; do
    echo "📂 $repo:"
    
    # 최근 PR 목록 가져오기
    RECENT_PRS=$(gh api repos/$repo/pulls --jq --arg since "$SINCE_DATE" '.[] | select(.created_at > $since) | .number' 2>/dev/null || echo "")
    
    if [ -z "$RECENT_PRS" ]; then
        echo "   📝 No recent PRs"
        continue
    fi
    
    REPO_PR_COUNT=$(echo "$RECENT_PRS" | wc -l)
    REPO_AI_REVIEWED=0
    REPO_AI_COMMENTS=0
    
    for pr_num in $RECENT_PRS; do
        TOTAL_PRS=$((TOTAL_PRS + 1))
        
        # PR 댓글에서 AI 리뷰 확인
        AI_COMMENTS_IN_PR=$(gh api repos/$repo/issues/$pr_num/comments --jq '.[] | select(.body | contains("🤖 AI") or contains("Claude") or contains("AI Review")) | .id' 2>/dev/null | wc -l)
        
        if [ "$AI_COMMENTS_IN_PR" -gt 0 ]; then
            AI_REVIEWED_PRS=$((AI_REVIEWED_PRS + 1))
            REPO_AI_REVIEWED=$((REPO_AI_REVIEWED + 1))
            REPO_AI_COMMENTS=$((REPO_AI_COMMENTS + AI_COMMENTS_IN_PR))
            AI_COMMENTS=$((AI_COMMENTS + AI_COMMENTS_IN_PR))
            echo "   ✅ PR #$pr_num: $AI_COMMENTS_IN_PR AI review comments"
        else
            echo "   ⭕ PR #$pr_num: No AI review"
        fi
    done
    
    if [ $REPO_AI_REVIEWED -gt 0 ]; then
        COVERAGE=$(( (REPO_AI_REVIEWED * 100) / REPO_PR_COUNT ))
        echo "   📊 AI Review Coverage: $REPO_AI_REVIEWED/$REPO_PR_COUNT PRs ($COVERAGE%)"
    fi
    
    echo ""
done

echo "📈 Overall Statistics"
echo "===================="
echo "🔢 Total PRs: $TOTAL_PRS"
echo "🤖 AI Reviewed PRs: $AI_REVIEWED_PRS"

if [ $TOTAL_PRS -gt 0 ]; then
    OVERALL_COVERAGE=$(( (AI_REVIEWED_PRS * 100) / TOTAL_PRS ))
    echo "📊 AI Review Coverage: $OVERALL_COVERAGE%"
else
    echo "📊 AI Review Coverage: N/A"
fi

echo "💬 Total AI Comments: $AI_COMMENTS"

# 웹훅 상태 확인
echo ""
echo "🔧 System Status"
echo "================"

# 웹훅 상태
WEBHOOK_STATUS=$("$SCRIPT_DIR/check-org-webhook.sh" "$ORGANIZATION" 2>/dev/null | grep -q "Claude Review webhook found" && echo "✅ Active" || echo "❌ Not Found")
echo "🌐 Organization Webhook: $WEBHOOK_STATUS"

# 서버 상태 (포트 3000 확인)
if curl -s --max-time 5 http://localhost:3000/health > /dev/null 2>&1; then
    SERVER_STATUS="✅ Running"
else
    SERVER_STATUS="❌ Not Running"
fi
echo "🖥️ Webhook Server: $SERVER_STATUS"

# SubAgent 확인
echo "🤖 SubAgents Status:"
AGENTS=("security-reviewer" "architecture-reviewer" "performance-reviewer" "ux-reviewer")
for agent in "${AGENTS[@]}"; do
    if claude --agent "$agent" --help > /dev/null 2>&1; then
        echo "   ✅ $agent"
    else
        echo "   ❌ $agent"
    fi
done

# 최근 로그 (서버가 실행 중인 경우)
if [ -f "$PROJECT_ROOT/logs/webhook-server.log" ]; then
    echo ""
    echo "📋 Recent Activity (Last 5 entries)"
    echo "===================================="
    tail -5 "$PROJECT_ROOT/logs/webhook-server.log"
fi

echo ""
echo "🔗 Useful Links"
echo "==============="
echo "• Organization Webhooks: https://github.com/orgs/$ORGANIZATION/settings/hooks"
echo "• GitHub API Rate Limit: https://api.github.com/rate_limit"
echo "• Local Server Health: http://localhost:3000/health"
echo "• Local Server Status: http://localhost:3000/status"

# 추천사항
echo ""
echo "💡 Recommendations"
echo "=================="

if [ $OVERALL_COVERAGE -lt 80 ] && [ $TOTAL_PRS -gt 0 ]; then
    echo "📈 Consider investigating why AI review coverage is below 80%"
fi

if [ "$WEBHOOK_STATUS" = "❌ Not Found" ]; then
    echo "🔧 Set up organization webhook: $SCRIPT_DIR/setup-org-webhook.sh $ORGANIZATION \$GITHUB_WEBHOOK_SECRET"
fi

if [ "$SERVER_STATUS" = "❌ Not Running" ]; then
    echo "🚀 Start webhook server: $SCRIPT_DIR/start-webhook-server.sh"
fi

if [ $AI_COMMENTS -eq 0 ]; then
    echo "🧪 Test the system by creating a test PR in any repository"
fi