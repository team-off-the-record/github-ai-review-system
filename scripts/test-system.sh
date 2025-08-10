#!/bin/bash
# GitHub Organization AI Review System 전체 테스트 스크립트

set -e

# 스크립트 디렉토리 및 프로젝트 루트 설정
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo "🧪 GitHub Organization AI Review System 테스트"
echo "============================================="
echo "📁 Project Directory: $PROJECT_ROOT"
echo ""

# 1. 환경변수 확인
echo "1️⃣ 환경변수 확인"
echo "=================="
if [ -z "$GITHUB_WEBHOOK_TOKEN" ] || [ -z "$GITHUB_WEBHOOK_SECRET" ] || [ -z "$ORGANIZATION_NAME" ]; then
    echo "❌ 환경변수가 설정되지 않았습니다."
    echo "   ./scripts/setup-env-simple.sh 실행하여 설정하세요."
    exit 1
fi
echo "✅ 환경변수 설정 완료"
echo ""

# 2. GitHub CLI 인증 확인
echo "2️⃣ GitHub CLI 인증 확인"
echo "======================"
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI 인증 필요"
    echo "   gh auth login 실행하세요"
    exit 1
fi

GITHUB_USER=$(gh api user --jq '.login')
echo "✅ GitHub CLI 인증됨 (사용자: $GITHUB_USER)"
echo ""

# 3. Organization 접근 권한 확인
echo "3️⃣ Organization 접근 권한 확인"
echo "============================"
if ! gh api orgs/$ORGANIZATION_NAME > /dev/null 2>&1; then
    echo "❌ Organization '$ORGANIZATION_NAME' 접근 불가"
    echo "   Organization 이름 확인 또는 권한 요청 필요"
    exit 1
fi
echo "✅ Organization '$ORGANIZATION_NAME' 접근 가능"
echo ""

# 4. Claude Code SubAgent 확인
echo "4️⃣ Claude Code SubAgent 확인"
echo "==========================="
AGENTS=("security-reviewer" "architecture-reviewer" "performance-reviewer" "ux-reviewer")

# SubAgent 파일 존재 확인
AGENT_DIR="$HOME/.claude/agents"
if [ ! -d "$AGENT_DIR" ]; then
    echo "❌ SubAgent 디렉토리가 존재하지 않습니다: $AGENT_DIR"
    echo "   Claude Code SubAgent를 먼저 설정하세요"
    exit 1
fi

for agent in "${AGENTS[@]}"; do
    AGENT_FILE="$AGENT_DIR/$agent.md"
    if [ -f "$AGENT_FILE" ]; then
        echo "✅ $agent SubAgent 파일 존재"
        
        # SubAgent 설정 확인 (다양한 형식 지원)
        if head -10 "$AGENT_FILE" | grep -q -E "(name.*$agent|## $agent|model.*sonnet)" 2>/dev/null; then
            echo "   ✅ $agent SubAgent 설정 확인됨"
        else
            echo "   ⚠️  $agent SubAgent 설정 형식을 확인하세요"
        fi
    else
        echo "❌ $agent SubAgent 파일이 존재하지 않습니다: $AGENT_FILE"
        echo "   SubAgent를 먼저 설정하세요"
        exit 1
    fi
done

echo "✅ 모든 SubAgent 파일이 정상적으로 설정되어 있습니다"
echo ""
echo "💡 SubAgent 사용 안내:"
echo "   - SubAgent는 Claude Code 대화 중 자동으로 선택됩니다"
echo "   - '--agent' 옵션은 존재하지 않으며, 자연어로 요청합니다"
echo "   - 웹훅 서버에서 자동으로 4개 SubAgent를 병렬 호출합니다"
echo ""

# 5. 웹훅 설정 테스트
echo "5️⃣ 웹훅 설정 테스트"
echo "=================="
echo "Organization 웹훅을 설정합니다..."
if "$SCRIPT_DIR/setup-org-webhook.sh" "$ORGANIZATION_NAME" "$GITHUB_WEBHOOK_SECRET"; then
    echo "✅ 웹훅 설정 성공"
else
    echo "❌ 웹훅 설정 실패"
    exit 1
fi
echo ""

# 6. 웹훅 상태 확인
echo "6️⃣ 웹훅 상태 확인"
echo "================"
if "$SCRIPT_DIR/check-org-webhook.sh" "$ORGANIZATION_NAME" | grep -q "Claude Review webhook found"; then
    echo "✅ 웹훅 상태 정상"
else
    echo "❌ 웹훅 상태 이상"
    exit 1
fi
echo ""

# 7. Node.js 의존성 확인
echo "7️⃣ Node.js 의존성 확인"
echo "===================="
if [ ! -d "node_modules" ]; then
    echo "📦 Installing Node.js dependencies..."
    npm install
fi
echo "✅ Node.js 의존성 준비됨"
echo ""

# 8. 로그 디렉토리 준비
echo "8️⃣ 로그 디렉토리 준비"
echo "===================="
mkdir -p "$PROJECT_ROOT/logs"
touch "$PROJECT_ROOT/logs/webhook-server.log"
echo "✅ 로그 디렉토리 준비됨: $PROJECT_ROOT/logs/"
echo ""

# 9. 리뷰 스킵 체커 테스트
echo "9️⃣ 리뷰 스킵 체커 테스트"
echo "======================="
if node src/review-skip-checker.js | grep -q "리뷰 스킵 체커 테스트"; then
    echo "✅ 리뷰 스킵 체커 정상 작동"
else
    echo "❌ 리뷰 스킵 체커 오류"
    exit 1
fi
echo ""

echo "🎉 시스템 준비 완료!"
echo "==================="
echo "프로젝트 위치: $PROJECT_ROOT"
echo ""
echo "🚀 다음 단계:"
echo "1. 웹훅 서버 시작: cd $PROJECT_ROOT && ./scripts/start-webhook-server.sh"
echo "2. 테스트 PR 생성으로 시스템 검증"
echo "3. 로그 확인: tail -f $PROJECT_ROOT/logs/webhook-server.log"