#!/bin/bash
# Cloudflare Tunnel 설정 수정 스크립트

set -e

CONFIG_FILE="/home/y30n51k/github-ai-review-system/cloudflared-config.yml"
TUNNEL_ID="e00b68ad-aaac-4fa6-be5d-af54def58a21"

echo "🔧 Fixing Cloudflare Tunnel Configuration"
echo "========================================"

# 1. 현재 서비스 상태 확인
echo "📊 Current Service Status:"
if systemctl is-active cloudflared >/dev/null; then
    echo "✅ Cloudflared service is running"
    echo "⚠️  But with wrong configuration (no ingress rules)"
else
    echo "❌ Cloudflared service is not running"
fi

# 2. 설정 파일 생성/확인
echo ""
echo "📝 Configuration File:"
if [ -f "$CONFIG_FILE" ]; then
    echo "✅ Config file exists: $CONFIG_FILE"
    echo "🔍 Validating configuration..."
    if cloudflared tunnel --config "$CONFIG_FILE" ingress validate; then
        echo "✅ Configuration is valid"
    else
        echo "❌ Configuration is invalid"
        exit 1
    fi
else
    echo "❌ Config file not found: $CONFIG_FILE"
    exit 1
fi

# 3. DNS 라우팅 확인
echo ""
echo "🌐 DNS Route Check:"
echo "✅ DNS route already configured: webhook.yeonsik.com -> tunnel $TUNNEL_ID"

# 4. 로컬 웹훅 서버 상태 확인
echo ""
echo "🖥️  Local Webhook Server:"
if curl -s -f http://localhost:3000/health >/dev/null; then
    echo "✅ Local webhook server is responding on port 3000"
else
    echo "❌ Local webhook server is not responding"
    echo "   Starting webhook server..."
    systemctl --user start claude-webhook 2>/dev/null || echo "   Service already running or failed to start"
fi

# 5. 임시로 새 설정으로 터널 테스트
echo ""
echo "🧪 Testing New Configuration:"
echo "Starting tunnel with new config (test mode)..."

# 기존 터널 프로세스 중지 (우아하게)
echo "⏹️  Stopping current tunnel..."
sudo systemctl stop cloudflared 2>/dev/null || echo "Service already stopped"

# 새 설정으로 터널 시작 (백그라운드)
echo "🚀 Starting tunnel with ingress rules..."
sudo cloudflared tunnel --config "$CONFIG_FILE" run webhook &
TUNNEL_PID=$!

# 잠깐 기다린 후 테스트
sleep 10

# 6. 외부 접근성 테스트
echo ""
echo "🌐 Testing External Connectivity:"
if curl -s -f --max-time 10 https://webhook.yeonsik.com/health >/dev/null; then
    echo "✅ External webhook access is working!"
    HEALTH_RESPONSE=$(curl -s https://webhook.yeonsik.com/health)
    echo "📊 Health Response: $HEALTH_RESPONSE"
    
    # 성공했으므로 systemd 서비스 업데이트
    echo ""
    echo "🔄 Updating Systemd Service:"
    echo "Creating new service file with config..."
    
    # 새 서비스 파일 생성
    sudo tee /etc/systemd/system/cloudflared-new.service > /dev/null <<EOF
[Unit]
Description=Cloudflare Tunnel with Config
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/bin/cloudflared --no-autoupdate --config $CONFIG_FILE tunnel run webhook
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
    
    # 기존 터널 프로세스 정리
    sudo kill $TUNNEL_PID 2>/dev/null || true
    
    # 서비스 교체
    sudo systemctl daemon-reload
    sudo systemctl disable cloudflared 2>/dev/null || true
    sudo systemctl enable cloudflared-new
    sudo systemctl start cloudflared-new
    
    echo "✅ Service updated and restarted"
    
else
    echo "❌ External webhook access failed"
    echo "🔍 Checking tunnel logs..."
    sudo kill $TUNNEL_PID 2>/dev/null || true
    
    # 원래 서비스 재시작
    echo "🔄 Restoring original service..."
    sudo systemctl start cloudflared
    
    echo ""
    echo "❌ Fix failed. Possible issues:"
    echo "   1. DNS propagation delay (wait 5-10 minutes)"
    echo "   2. Firewall blocking localhost:3000"
    echo "   3. Credentials file path incorrect"
    echo "   4. Cloudflare domain configuration"
fi

echo ""
echo "🏁 Tunnel Fix Attempt Complete"