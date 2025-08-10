#!/bin/bash
# Organization 전체 리뷰 통계 조회 스크립트

ORGANIZATION=$1
DAYS=${2:-7}

if [ -z "$ORGANIZATION" ]; then
    echo "Usage: $0 <organization-name> [days]"
    echo "Example: $0 team-off-the-record 7"
    exit 1
fi

echo "📊 AI Review Statistics for $ORGANIZATION (Last $DAYS days)"
echo "================================================"

# Organization 저장소 목록
echo "🔍 Fetching repositories..."
REPOS=$(gh api orgs/$ORGANIZATION/repos --paginate --jq '.[].full_name' 2>/dev/null)

if [ -z "$REPOS" ]; then
    echo "❌ No repositories found or access denied"
    exit 1
fi

TOTAL_REPOS=0
TOTAL_PRS=0
TOTAL_AI_REVIEWS=0
RECENT_DATE=$(date -d "$DAYS days ago" -I)

echo "📅 Analyzing PRs since: $RECENT_DATE"
echo ""

for repo in $REPOS; do
    TOTAL_REPOS=$((TOTAL_REPOS + 1))
    echo "📁 $repo:"
    
    # 최근 PR 목록 조회
    RECENT_PRS=$(gh api repos/$repo/pulls \
        --jq '.[] | select(.created_at > "'$RECENT_DATE'") | .number' 2>/dev/null)
    
    if [ -z "$RECENT_PRS" ]; then
        echo "  📝 No recent PRs"
        continue
    fi
    
    REPO_PR_COUNT=0
    REPO_AI_COUNT=0
    
    for pr_num in $RECENT_PRS; do
        REPO_PR_COUNT=$((REPO_PR_COUNT + 1))
        TOTAL_PRS=$((TOTAL_PRS + 1))
        
        # PR 댓글에서 AI 리뷰 확인
        AI_COMMENTS=$(gh api repos/$repo/issues/$pr_num/comments \
            --jq '.[] | select(.user.login == "claude-bot" or (.body | contains("🤖 AI Review") or contains("🤖 AI Code Review"))) | .created_at' 2>/dev/null | wc -l)
        
        if [ "$AI_COMMENTS" -gt 0 ]; then
            REPO_AI_COUNT=$((REPO_AI_COUNT + 1))
            TOTAL_AI_REVIEWS=$((TOTAL_AI_REVIEWS + 1))
            
            # PR 제목 가져오기
            PR_TITLE=$(gh api repos/$repo/pulls/$pr_num --jq '.title' 2>/dev/null)
            echo "  ✅ PR #$pr_num: \"${PR_TITLE:0:50}...\" ($AI_COMMENTS AI comments)"
        else
            # 스킵된 이유 확인
            SKIP_COMMENTS=$(gh api repos/$repo/issues/$pr_num/comments \
                --jq '.[] | select(.body | contains("🤖 AI Review Skipped")) | .created_at' 2>/dev/null | wc -l)
            
            if [ "$SKIP_COMMENTS" -gt 0 ]; then
                echo "  ⏭️  PR #$pr_num: Review skipped"
            else
                echo "  ❓ PR #$pr_num: No AI review found"
            fi
        fi
    done
    
    if [ "$REPO_PR_COUNT" -gt 0 ]; then
        COVERAGE_PERCENT=$((REPO_AI_COUNT * 100 / REPO_PR_COUNT))
        echo "  📊 Repository Stats: $REPO_AI_COUNT/$REPO_PR_COUNT PRs reviewed (${COVERAGE_PERCENT}%)"
    fi
    echo ""
done

# 전체 통계 출력
echo "🎯 Overall Statistics"
echo "===================="
echo "📁 Total Repositories: $TOTAL_REPOS"
echo "📝 Total PRs (last $DAYS days): $TOTAL_PRS"
echo "🤖 PRs with AI Reviews: $TOTAL_AI_REVIEWS"

if [ "$TOTAL_PRS" -gt 0 ]; then
    TOTAL_COVERAGE=$((TOTAL_AI_REVIEWS * 100 / TOTAL_PRS))
    echo "📊 AI Review Coverage: ${TOTAL_COVERAGE}%"
    
    if [ "$TOTAL_COVERAGE" -ge 80 ]; then
        echo "🎉 Excellent coverage!"
    elif [ "$TOTAL_COVERAGE" -ge 60 ]; then
        echo "👍 Good coverage"
    elif [ "$TOTAL_COVERAGE" -ge 40 ]; then
        echo "⚠️  Fair coverage - consider optimizing"
    else
        echo "🔴 Low coverage - needs attention"
    fi
else
    echo "📊 No PRs found in the specified period"
fi

# 웹훅 상태 확인
echo ""
echo "🔗 Webhook Status Check"
echo "====================="
WEBHOOK_STATUS=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url | contains("webhook.yeonsik.com")) | .active' 2>/dev/null)

if [ "$WEBHOOK_STATUS" = "true" ]; then
    echo "✅ Organization webhook is active"
    
    # 최근 웹훅 전송 확인
    WEBHOOK_ID=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url | contains("webhook.yeonsik.com")) | .id' 2>/dev/null)
    if [ -n "$WEBHOOK_ID" ]; then
        echo "🚀 Checking recent webhook deliveries..."
        RECENT_DELIVERIES=$(gh api orgs/$ORGANIZATION/hooks/$WEBHOOK_ID/deliveries --jq '.[0:3] | .[] | "ID: \(.id) | Event: \(.event) | Status: \(.status) | Time: \(.delivered_at)"' 2>/dev/null)
        if [ -n "$RECENT_DELIVERIES" ]; then
            echo "$RECENT_DELIVERIES"
        else
            echo "⚠️  No recent deliveries found"
        fi
    fi
else
    echo "❌ Organization webhook is not active or not found"
fi

echo ""
echo "📈 Generated on: $(date)"