#!/bin/bash
# 간단한 터널 연결 테스트

echo "🔧 Simple Cloudflare Tunnel Test"
echo "================================"

# 1. 로컬 웹훅 서버 확인
echo "🖥️  Checking local webhook server..."
if curl -s -f http://localhost:3000/health >/dev/null; then
    echo "✅ Local server responding on port 3000"
    LOCAL_HEALTH=$(curl -s http://localhost:3000/health)
    echo "📊 Local Health: $LOCAL_HEALTH"
else
    echo "❌ Local server not responding on port 3000"
    echo "🚀 Starting webhook server..."
    systemctl --user start claude-webhook
    sleep 3
fi

# 2. 터널 상태 확인
echo ""
echo "🌐 Checking tunnel status..."
if curl -s --max-time 5 https://webhook.yeonsik.com/health 2>/dev/null; then
    echo "✅ Tunnel is working!"
    EXTERNAL_HEALTH=$(curl -s https://webhook.yeonsik.com/health)
    echo "📊 External Health: $EXTERNAL_HEALTH"
    
    # 웹훅 테스트 페이로드 전송
    echo ""
    echo "🧪 Testing webhook endpoint..."
    curl -X POST https://webhook.yeonsik.com/webhook \
        -H "Content-Type: application/json" \
        -H "X-GitHub-Event: ping" \
        -H "X-Hub-Signature-256: sha256=test" \
        -d '{"zen":"This is a test","hook_id":1}' \
        -w "\nHTTP Status: %{http_code}\n" \
        2>/dev/null || echo "Webhook test failed"
        
else
    echo "❌ Tunnel not working"
    
    # 터널 연결 상태 확인
    echo ""
    echo "🔍 Diagnosing tunnel..."
    
    echo "📋 Active tunnels:"
    cloudflared tunnel list
    
    echo ""
    echo "📋 Tunnel info:"
    cloudflared tunnel info webhook
    
    echo ""
    echo "📋 Current cloudflared process:"
    ps aux | grep cloudflared | grep -v grep
    
    echo ""
    echo "🔧 Possible fixes:"
    echo "1. Wait 5-10 minutes for DNS propagation"
    echo "2. Restart cloudflared service: sudo systemctl restart cloudflared" 
    echo "3. Check ingress rules in Cloudflare dashboard"
    echo "4. Use alternative tunnel service (ngrok, serveo, etc.)"
fi

echo ""
echo "📈 Test completed at: $(date)"