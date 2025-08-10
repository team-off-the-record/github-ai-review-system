#!/bin/bash
# Organization 웹훅 상태 확인

ORGANIZATION=$1

if [ -z "$ORGANIZATION" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

echo "🔍 Checking webhooks for organization: $ORGANIZATION"

WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve webhooks"
    exit 1
fi

WEBHOOK_COUNT=$(echo "$WEBHOOKS" | jq '. | length')
echo "📋 Found $WEBHOOK_COUNT webhook(s)"

if [ "$WEBHOOK_COUNT" -gt 0 ]; then
    echo "$WEBHOOKS" | jq -r '.[] | "ID: \(.id) | URL: \(.config.url) | Active: \(.active) | Events: \(.events | join(", "))"'
    
    # Claude Review 웹훅 확인
    WEBHOOK_URL="https://webhook.yeonsik.com/webhook"
    CLAUDE_WEBHOOK=$(echo "$WEBHOOKS" | jq --arg url "$WEBHOOK_URL" '.[] | select(.config.url == $url)')
    
    if [ -n "$CLAUDE_WEBHOOK" ] && [ "$CLAUDE_WEBHOOK" != "null" ]; then
        echo "✅ Claude Review webhook is active"
    else
        echo "❌ Claude Review webhook not found"
    fi
fi