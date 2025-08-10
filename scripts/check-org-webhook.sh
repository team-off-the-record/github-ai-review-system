#!/bin/bash
# Organization 웹훅 상태 확인

ORGANIZATION=$1

if [ -z "$ORGANIZATION" ]; then
    echo "Usage: $0 <organization-name>"
    echo "Example: $0 myorg"
    echo ""
    echo "환경변수에서 값을 가져오려면:"
    echo "$0 \$ORGANIZATION_NAME"
    exit 1
fi

echo "🔍 Checking webhooks for organization: $ORGANIZATION"
echo "================================================="

WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve webhooks"
    echo "   Check organization name and access permissions"
    exit 1
fi

WEBHOOK_COUNT=$(echo "$WEBHOOKS" | jq '. | length')
echo "📋 Found $WEBHOOK_COUNT webhook(s)"

if [ "$WEBHOOK_COUNT" -gt 0 ]; then
    echo ""
    echo "Webhook Details:"
    echo "=================="
    echo "$WEBHOOKS" | jq -r '.[] | "ID: \(.id) | URL: \(.config.url) | Active: \(.active) | Events: \(.events | join(", "))"'

    # Claude Review 웹훅 확인
    WEBHOOK_URL="https://webhook.yeonsik.kim/webhook"
    CLAUDE_WEBHOOK=$(echo "$WEBHOOKS" | jq --arg url "$WEBHOOK_URL" '.[] | select(.config.url == $url)')

    echo ""
    if [ -n "$CLAUDE_WEBHOOK" ] && [ "$CLAUDE_WEBHOOK" != "null" ]; then
        HOOK_ID=$(echo "$CLAUDE_WEBHOOK" | jq -r '.id')
        HOOK_ACTIVE=$(echo "$CLAUDE_WEBHOOK" | jq -r '.active')
        HOOK_EVENTS=$(echo "$CLAUDE_WEBHOOK" | jq -r '.events | join(", ")')
        echo "✅ Claude Review webhook found:"
        echo "   ID: $HOOK_ID"
        echo "   Active: $HOOK_ACTIVE"
        echo "   Events: $HOOK_EVENTS"
    else
        echo "❌ Claude Review webhook not found"
        echo "   Expected URL: $WEBHOOK_URL"
    fi
else
    echo "ℹ️  No webhooks configured for this organization"
fi

echo ""
echo "🔗 Manage webhooks at: https://github.com/orgs/$ORGANIZATION/settings/hooks"