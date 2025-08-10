#!/bin/bash
# 웹훅 시스템 종합 건강 상태 모니터링

ORGANIZATION=${1:-"team-off-the-record"}

echo "🏥 Claude AI Review System Health Check"
echo "======================================"
echo "Organization: $ORGANIZATION"
echo "Timestamp: $(date)"
echo ""

# 1. 로컬 웹훅 서버 상태 확인
echo "🖥️  Local Webhook Server Status"
echo "-----------------------------"

# 서비스 상태
if systemctl --user is-active claude-webhook >/dev/null 2>&1; then
    echo "✅ Service Status: Running"
    UPTIME=$(systemctl --user show claude-webhook --property=ActiveEnterTimestamp --value)
    echo "⏰ Started: $UPTIME"
else
    echo "❌ Service Status: Stopped"
fi

# 포트 확인
if netstat -tuln 2>/dev/null | grep -q ":3000"; then
    echo "✅ Port 3000: Listening"
else
    echo "❌ Port 3000: Not listening"
fi

# Health 엔드포인트 테스트
if curl -s -f http://localhost:3000/health >/dev/null 2>&1; then
    echo "✅ Health Endpoint: Responding"
    HEALTH_RESPONSE=$(curl -s http://localhost:3000/health | jq -r '.status' 2>/dev/null || echo "N/A")
    echo "📊 Health Status: $HEALTH_RESPONSE"
else
    echo "❌ Health Endpoint: Not responding"
fi

echo ""

# 2. GitHub Organization 웹훅 상태
echo "🐙 GitHub Organization Webhook"
echo "-----------------------------"

WEBHOOK_INFO=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url | contains("webhook.yeonsik.com"))' 2>/dev/null)

if [ -n "$WEBHOOK_INFO" ] && [ "$WEBHOOK_INFO" != "null" ]; then
    WEBHOOK_ACTIVE=$(echo "$WEBHOOK_INFO" | jq -r '.active')
    WEBHOOK_ID=$(echo "$WEBHOOK_INFO" | jq -r '.id')
    WEBHOOK_EVENTS=$(echo "$WEBHOOK_INFO" | jq -r '.events | join(", ")')
    
    echo "✅ Webhook Registered: Yes (ID: $WEBHOOK_ID)"
    echo "🔄 Active: $WEBHOOK_ACTIVE"
    echo "📡 Events: $WEBHOOK_EVENTS"
    
    # 최근 전송 상태 확인
    echo ""
    echo "📤 Recent Deliveries (Last 5):"
    DELIVERIES=$(gh api orgs/$ORGANIZATION/hooks/$WEBHOOK_ID/deliveries --jq '.[0:5]' 2>/dev/null)
    
    if [ -n "$DELIVERIES" ] && [ "$DELIVERIES" != "[]" ]; then
        echo "$DELIVERIES" | jq -r '.[] | "  • \(.delivered_at) | \(.event) | \(.status) (\(.status_code))"'
        
        # 성공률 계산
        TOTAL_DELIVERIES=$(echo "$DELIVERIES" | jq '. | length')
        SUCCESS_DELIVERIES=$(echo "$DELIVERIES" | jq '[.[] | select(.status_code == 200)] | length')
        
        if [ "$TOTAL_DELIVERIES" -gt 0 ]; then
            SUCCESS_RATE=$((SUCCESS_DELIVERIES * 100 / TOTAL_DELIVERIES))
            echo "📊 Recent Success Rate: ${SUCCESS_RATE}% ($SUCCESS_DELIVERIES/$TOTAL_DELIVERIES)"
        fi
    else
        echo "  ⚠️  No recent deliveries found"
    fi
else
    echo "❌ Webhook Registered: No"
fi

echo ""

# 3. Cloudflare Tunnel 상태 (외부 접근성)
echo "☁️  Cloudflare Tunnel Status"
echo "---------------------------"

if curl -s -f --max-time 10 https://webhook.yeonsik.com/health >/dev/null 2>&1; then
    echo "✅ External Access: Available"
    EXTERNAL_HEALTH=$(curl -s https://webhook.yeonsik.com/health | jq -r '.status' 2>/dev/null || echo "N/A")
    echo "📊 External Health: $EXTERNAL_HEALTH"
else
    echo "❌ External Access: Failed"
    echo "⚠️  Check Cloudflare Tunnel configuration"
fi

echo ""

# 4. 필요한 환경 변수 확인
echo "🔧 Environment Configuration"
echo "----------------------------"

ENV_FILE="/home/y30n51k/github-ai-review-system/claude-webhook-server/.env"

if [ -f "$ENV_FILE" ]; then
    echo "✅ Environment File: Found"
    
    # .env 파일에서 설정 확인 (값은 보안상 표시하지 않음)
    if grep -q "GITHUB_WEBHOOK_SECRET" "$ENV_FILE"; then
        echo "✅ Webhook Secret: Configured"
    else
        echo "❌ Webhook Secret: Missing"
    fi
    
    if grep -q "GITHUB_WEBHOOK_TOKEN" "$ENV_FILE"; then
        echo "✅ GitHub Token: Configured"
    else
        echo "❌ GitHub Token: Missing"
    fi
    
    if grep -q "ORGANIZATION_NAME" "$ENV_FILE"; then
        ORG_NAME=$(grep "ORGANIZATION_NAME" "$ENV_FILE" | cut -d'=' -f2)
        echo "✅ Organization: $ORG_NAME"
    else
        echo "❌ Organization: Not configured"
    fi
else
    echo "❌ Environment File: Missing"
fi

echo ""

# 5. Claude Code MCP 서버 상태
echo "🤖 Claude Code MCP Servers"
echo "-------------------------"

MCP_STATUS=$(claude mcp list 2>/dev/null | grep -E "(github|Connected|Failed)")

if echo "$MCP_STATUS" | grep -q "smithery-ai-github.*Connected"; then
    echo "✅ GitHub MCP: Connected"
else
    echo "❌ GitHub MCP: Not connected or failed"
fi

if echo "$MCP_STATUS" | grep -qE "(memory|sequential-thinking).*Connected"; then
    echo "✅ AI Agents MCP: Connected"
else
    echo "⚠️  AI Agents MCP: Check connection"
fi

echo ""

# 6. 최근 로그 요약
echo "📋 Recent Activity Summary"
echo "-------------------------"

LOG_FILE="/home/y30n51k/github-ai-review-system/claude-webhook-server/logs/combined.log"

if [ -f "$LOG_FILE" ]; then
    echo "📊 Recent Events (Last 10):"
    tail -10 "$LOG_FILE" | grep -E "(Processing PR|Review completed|Review failed)" | tail -5 | while read line; do
        echo "  • $line"
    done
    
    # 에러 카운트
    ERROR_COUNT=$(grep -c "error\|ERROR\|failed\|FAILED" "$LOG_FILE" 2>/dev/null || echo "0")
    echo "🔴 Recent Errors: $ERROR_COUNT"
else
    echo "⚠️  Log file not found: $LOG_FILE"
fi

echo ""

# 7. 시스템 리소스 사용량
echo "💻 System Resources"
echo "------------------"

# 웹훅 서버 프로세스 리소스 사용량
WEBHOOK_PID=$(pgrep -f "webhook-server.js" | head -1)
if [ -n "$WEBHOOK_PID" ]; then
    CPU_USAGE=$(ps -p "$WEBHOOK_PID" -o %cpu --no-headers 2>/dev/null || echo "N/A")
    MEM_USAGE=$(ps -p "$WEBHOOK_PID" -o %mem --no-headers 2>/dev/null || echo "N/A")
    echo "🔄 CPU Usage: ${CPU_USAGE}%"
    echo "💾 Memory Usage: ${MEM_USAGE}%"
else
    echo "❌ Webhook process not found"
fi

# 디스크 사용량 (/tmp for temp files)
TEMP_USAGE=$(df /tmp | tail -1 | awk '{print $5}' 2>/dev/null || echo "N/A")
echo "💽 /tmp Usage: $TEMP_USAGE"

echo ""

# 8. 종합 건강 점수 계산
echo "🏆 Overall Health Score"
echo "======================"

SCORE=0
MAX_SCORE=8

# 각 체크 항목별 점수
systemctl --user is-active claude-webhook >/dev/null 2>&1 && SCORE=$((SCORE + 1))
netstat -tuln 2>/dev/null | grep -q ":3000" && SCORE=$((SCORE + 1))
curl -s -f http://localhost:3000/health >/dev/null 2>&1 && SCORE=$((SCORE + 1))
[ -n "$WEBHOOK_INFO" ] && [ "$WEBHOOK_INFO" != "null" ] && SCORE=$((SCORE + 1))
curl -s -f --max-time 5 https://webhook.yeonsik.com/health >/dev/null 2>&1 && SCORE=$((SCORE + 1))
[ -f "$ENV_FILE" ] && SCORE=$((SCORE + 1))
echo "$MCP_STATUS" | grep -q "smithery-ai-github.*Connected" && SCORE=$((SCORE + 1))
[ -n "$WEBHOOK_PID" ] && SCORE=$((SCORE + 1))

HEALTH_PERCENT=$((SCORE * 100 / MAX_SCORE))

echo "📊 Score: $SCORE/$MAX_SCORE ($HEALTH_PERCENT%)"

if [ "$HEALTH_PERCENT" -ge 90 ]; then
    echo "🟢 Status: Excellent - System fully operational"
elif [ "$HEALTH_PERCENT" -ge 75 ]; then
    echo "🟡 Status: Good - Minor issues detected"
elif [ "$HEALTH_PERCENT" -ge 50 ]; then
    echo "🟠 Status: Fair - Needs attention"
else
    echo "🔴 Status: Poor - Immediate action required"
fi

echo ""
echo "💡 Recommendations:"
if [ "$HEALTH_PERCENT" -lt 100 ]; then
    echo "   - Check failed components above"
    echo "   - Review logs for error details"
    echo "   - Restart services if needed"
    echo "   - Verify network connectivity"
else
    echo "   - System is healthy! 🎉"
fi