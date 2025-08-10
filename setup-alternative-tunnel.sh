#!/bin/bash
# 대체 터널 서비스로 즉시 해결

echo "🚀 Setting up Alternative Tunnel Service"
echo "======================================="

# 1. Serveo.net 사용 (설치 불필요)
echo "🔗 Option 1: Using serveo.net (no installation required)"
echo "Command to run in separate terminal:"
echo "ssh -R webhook-ai-review:80:localhost:3000 serveo.net"
echo ""
echo "This will create: https://webhook-ai-review.serveo.net"
echo ""

# 2. ngrok 설치 및 사용
echo "🔗 Option 2: Installing ngrok"
if ! command -v ngrok &> /dev/null; then
    echo "📥 Installing ngrok..."
    curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
    echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
    sudo apt update && sudo apt install ngrok -y
else
    echo "✅ ngrok already installed"
fi

if command -v ngrok &> /dev/null; then
    echo "🚀 Starting ngrok tunnel..."
    echo "Command to run:"
    echo "ngrok http 3000"
    echo ""
    echo "This will provide a public URL like: https://abc123.ngrok.io"
fi

echo ""
echo "📋 Next Steps:"
echo "1. Choose one tunnel service and get the public URL"
echo "2. Update GitHub webhook URL to the new tunnel URL"
echo "3. Test the system"

echo ""
echo "🔧 Quick webhook URL update command:"
echo 'gh api orgs/team-off-the-record/hooks/562940845 \\'
echo '  --method PATCH \\'
echo '  --field config.url="https://YOUR_TUNNEL_URL/webhook"'