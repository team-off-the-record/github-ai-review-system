#!/bin/bash
# GitHub Organization PR 자동 리뷰 시스템 환경변수 설정

echo "🔧 환경변수 설정 가이드"
echo "========================="
echo ""
echo "다음 환경변수들을 ~/.bashrc에 추가해야 합니다:"
echo ""
echo "# GitHub Organization AI Review System"
echo "export ANTHROPIC_API_KEY=\"your_anthropic_api_key_here\""
echo "export GITHUB_WEBHOOK_TOKEN=\"your_github_personal_access_token_here\"  # repo, admin:org 권한 필요"
echo "export GITHUB_WEBHOOK_SECRET=\"your_webhook_secret_here\""
echo "export ORGANIZATION_NAME=\"your_github_organization_name\""
echo ""
echo "📋 설정 방법:"
echo "1. ~/.bashrc 파일을 편집기로 열기"
echo "2. 위 환경변수들을 파일 끝에 추가"
echo "3. 실제 값으로 교체"
echo "4. source ~/.bashrc 실행"
echo ""
echo "🔑 GitHub Token 생성 방법:"
echo "1. GitHub → Settings → Developer settings → Personal access tokens"
echo "2. Generate new token (classic)"
echo "3. 권한 선택: repo (모든 항목), admin:org (read:org, write:org)"
echo ""
echo "⚠️ 중요: Organization owner 권한이 있는 계정의 토큰이 필요합니다!"
echo ""
echo "현재 환경변수 상태:"
if [ -n "$ANTHROPIC_API_KEY" ]; then
    echo "✅ ANTHROPIC_API_KEY: 설정됨"
else
    echo "❌ ANTHROPIC_API_KEY: 설정 필요"
fi

if [ -n "$GITHUB_WEBHOOK_TOKEN" ]; then
    echo "✅ GITHUB_WEBHOOK_TOKEN: 설정됨"
else
    echo "❌ GITHUB_WEBHOOK_TOKEN: 설정 필요"
fi

if [ -n "$GITHUB_WEBHOOK_SECRET" ]; then
    echo "✅ GITHUB_WEBHOOK_SECRET: 설정됨"
else
    echo "❌ GITHUB_WEBHOOK_SECRET: 설정 필요"
fi

if [ -n "$ORGANIZATION_NAME" ]; then
    echo "✅ ORGANIZATION_NAME: 설정됨 ($ORGANIZATION_NAME)"
else
    echo "❌ ORGANIZATION_NAME: 설정 필요"
fi

echo ""
echo "환경변수가 모두 설정되면 이 스크립트를 다시 실행하여 확인하세요."