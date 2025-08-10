#!/bin/bash
# PR에 대한 수동 AI 리뷰 트리거 스크립트

REPO=$1
PR_NUMBER=$2

if [ -z "$REPO" ] || [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 <owner/repo> <pr_number>"
    echo "Example: $0 team-off-the-record/off-the-record-server 1"
    exit 1
fi

echo "🚀 Triggering Manual AI Review"
echo "=============================="
echo "Repository: $REPO"
echo "PR Number: $PR_NUMBER"
echo "Timestamp: $(date)"
echo ""

# PR 존재 확인
echo "🔍 Checking PR existence..."
PR_DATA=$(gh api repos/$REPO/pulls/$PR_NUMBER 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$PR_DATA" ]; then
    echo "❌ PR #$PR_NUMBER not found in $REPO"
    exit 1
fi

PR_TITLE=$(echo "$PR_DATA" | jq -r '.title')
PR_STATE=$(echo "$PR_DATA" | jq -r '.state')
PR_AUTHOR=$(echo "$PR_DATA" | jq -r '.user.login')

echo "✅ PR Found:"
echo "   Title: $PR_TITLE"
echo "   State: $PR_STATE"
echo "   Author: $PR_AUTHOR"

if [ "$PR_STATE" != "open" ]; then
    echo "⚠️  Warning: PR is not open (state: $PR_STATE)"
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""

# 기존 AI 리뷰 확인
echo "🔍 Checking for existing AI reviews..."
EXISTING_REVIEWS=$(gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '[.[] | select(.user.login == "claude-bot" or (.body | contains("🤖 AI Review") or contains("🤖 AI Code Review")))] | length' 2>/dev/null)

if [ "$EXISTING_REVIEWS" -gt 0 ]; then
    echo "⚠️  Found $EXISTING_REVIEWS existing AI review(s)"
    read -p "Trigger new review anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 1
    fi
fi

echo ""

# 수동 트리거 방법 선택
echo "🎯 Select trigger method:"
echo "1. Post comment trigger (@claude-bot review)"
echo "2. Direct webhook simulation (if local)"
echo "3. GitHub CLI comment with /review"

read -p "Choose method (1-3): " -n 1 -r METHOD
echo

case $METHOD in
    1)
        echo "📝 Posting trigger comment..."
        COMMENT_BODY="@claude-bot review

This is a manual trigger for AI review.

Requested by: $(gh api user --jq '.login')
Timestamp: $(date -Iseconds)
Reason: Manual review request"
        
        gh api repos/$REPO/issues/$PR_NUMBER/comments \
            --method POST \
            --field body="$COMMENT_BODY" > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Trigger comment posted successfully"
            echo "🔄 AI review should start processing..."
        else
            echo "❌ Failed to post trigger comment"
            exit 1
        fi
        ;;
    
    2)
        echo "🖥️  Simulating webhook locally..."
        if ! systemctl --user is-active claude-webhook >/dev/null; then
            echo "❌ Local webhook service is not running"
            echo "   Start with: systemctl --user start claude-webhook"
            exit 1
        fi
        
        # 간단한 테스트 페이로드 생성
        TEST_PAYLOAD="{
            \"action\": \"synchronize\",
            \"pull_request\": {
                \"number\": $PR_NUMBER,
                \"title\": \"$PR_TITLE\",
                \"user\": {\"login\": \"$PR_AUTHOR\"},
                \"head\": {\"sha\": \"test-sha\", \"ref\": \"test-branch\"},
                \"base\": {\"ref\": \"main\"}
            },
            \"repository\": {\"full_name\": \"$REPO\"},
            \"organization\": {\"login\": \"$(echo $REPO | cut -d'/' -f1)\"}
        }"
        
        # 웹훅 시크릿으로 서명 생성 (간단한 테스트용)
        echo "🔐 Sending test webhook..."
        curl -X POST http://localhost:3000/webhook \
            -H "Content-Type: application/json" \
            -H "X-GitHub-Event: pull_request" \
            -H "X-Hub-Signature-256: sha256=test-signature" \
            -d "$TEST_PAYLOAD" \
            -w "\nHTTP Status: %{http_code}\n" 2>/dev/null
        
        echo "⚠️  Note: This is a test simulation and may not work with signature verification"
        ;;
    
    3)
        echo "💬 Posting /review command..."
        REVIEW_COMMAND="/review

Manual AI review requested for PR #$PR_NUMBER

Details:
- Repository: $REPO
- Requested by: $(gh api user --jq '.login')  
- Timestamp: $(date -Iseconds)
- PR State: $PR_STATE

Please analyze this PR using all available AI reviewers."
        
        gh api repos/$REPO/issues/$PR_NUMBER/comments \
            --method POST \
            --field body="$REVIEW_COMMAND" > /dev/null
        
        if [ $? -eq 0 ]; then
            echo "✅ Review command posted successfully"
        else
            echo "❌ Failed to post review command"
            exit 1
        fi
        ;;
    
    *)
        echo "❌ Invalid selection"
        exit 1
        ;;
esac

echo ""
echo "⏱️  Monitoring Progress"
echo "======================"
echo "You can monitor the review progress with:"
echo "  • Check PR comments: gh pr view $PR_NUMBER --repo $REPO"
echo "  • Monitor webhook logs: journalctl --user -u claude-webhook -f"
echo "  • Check health status: ./webhook-health-monitor.sh"
echo ""

# 진행 상황 모니터링 옵션
read -p "Monitor review progress? (y/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "📊 Monitoring for new comments (Press Ctrl+C to stop)..."
    
    INITIAL_COMMENTS=$(gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '. | length')
    echo "Initial comment count: $INITIAL_COMMENTS"
    
    while true; do
        sleep 10
        CURRENT_COMMENTS=$(gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '. | length')
        
        if [ "$CURRENT_COMMENTS" -gt "$INITIAL_COMMENTS" ]; then
            echo "🎉 New comment detected! ($CURRENT_COMMENTS comments total)"
            
            # 최신 댓글 확인
            LATEST_COMMENT=$(gh api repos/$REPO/issues/$PR_NUMBER/comments --jq '.[-1].body' | head -100)
            if echo "$LATEST_COMMENT" | grep -q "🤖"; then
                echo "🤖 AI Review comment found!"
                echo "Preview:"
                echo "$LATEST_COMMENT" | head -5 | sed 's/^/  /'
                break
            fi
            INITIAL_COMMENTS=$CURRENT_COMMENTS
        else
            echo "⏳ Waiting for review... ($CURRENT_COMMENTS comments)"
        fi
    done
fi

echo ""
echo "✅ Manual review trigger completed!"
echo "Check the PR page: https://github.com/$REPO/pull/$PR_NUMBER"