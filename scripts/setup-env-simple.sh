#!/bin/bash
# GitHub Organization AI Review System 환경변수 설정 스크립트

set -e

# 색상 정의 - 터미널 지원 여부 확인
if [ -t 1 ] && command -v tput >/dev/null 2>&1 && tput colors >/dev/null 2>&1 && [ "$(tput colors)" -ge 8 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color
else
    # 색상 미지원 환경에서는 빈 문자열 사용
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    NC=''
fi

# 색상 출력 함수
print_colored() {
    if [ -n "$2" ]; then
        printf "%b%s%b\n" "$1" "$2" "$NC"
    else
        printf "%s\n" "$1"
    fi
}

echo -e "${CYAN}🔧 GitHub Organization AI Review System 환경변수 설정${NC}"
echo "============================================================="
echo ""
echo "이 스크립트는 필요한 5개 환경변수를 ~/.bashrc에 자동으로 추가합니다:"
echo "  1. GITHUB_WEBHOOK_TOKEN - GitHub API 접근용 토큰"
echo "  2. GITHUB_WEBHOOK_SECRET - 웹훅 보안용 비밀키"
echo "  3. ORGANIZATION_NAME - GitHub Organization 이름"
echo "  4. WEBHOOK_URL - Cloudflare Tunnel 웹훅 엔드포인트"
echo "  5. AI_REVIEW_LANGUAGE - AI 리뷰 언어 설정 (기본값: english)"
echo ""

# 현재 상태 확인
echo -e "${BLUE}📊 현재 환경변수 상태:${NC}"
echo "=========================="

GITHUB_WEBHOOK_TOKEN_SET=false
WEBHOOK_SECRET_SET=false
ORGANIZATION_SET=false
WEBHOOK_URL_SET=false
AI_REVIEW_LANGUAGE_SET=false

if [ -n "$GITHUB_WEBHOOK_TOKEN" ]; then
    echo -e "✅ ${GREEN}GITHUB_WEBHOOK_TOKEN: 설정됨${NC}"
    GITHUB_WEBHOOK_TOKEN_SET=true
else
    echo -e "❌ ${RED}GITHUB_WEBHOOK_TOKEN: 설정 필요${NC}"
fi

if [ -n "$GITHUB_WEBHOOK_SECRET" ]; then
    echo -e "✅ ${GREEN}GITHUB_WEBHOOK_SECRET: 설정됨${NC}"
    WEBHOOK_SECRET_SET=true
else
    echo -e "❌ ${RED}GITHUB_WEBHOOK_SECRET: 설정 필요${NC}"
fi

if [ -n "$ORGANIZATION_NAME" ]; then
    echo -e "✅ ${GREEN}ORGANIZATION_NAME: 설정됨 ($ORGANIZATION_NAME)${NC}"
    ORGANIZATION_SET=true
else
    echo -e "❌ ${RED}ORGANIZATION_NAME: 설정 필요${NC}"
fi

if [ -n "$WEBHOOK_URL" ]; then
    echo -e "✅ ${GREEN}WEBHOOK_URL: 설정됨 ($WEBHOOK_URL)${NC}"
    WEBHOOK_URL_SET=true
else
    echo -e "❌ ${RED}WEBHOOK_URL: 설정 필요${NC}"
fi

if [ -n "$AI_REVIEW_LANGUAGE" ]; then
    echo -e "✅ ${GREEN}AI_REVIEW_LANGUAGE: 설정됨 ($AI_REVIEW_LANGUAGE)${NC}"
    AI_REVIEW_LANGUAGE_SET=true
else
    echo -e "❌ ${RED}AI_REVIEW_LANGUAGE: 설정 필요 (기본값: english)${NC}"
fi

echo ""

# 모든 환경변수가 설정된 경우
if $GITHUB_WEBHOOK_TOKEN_SET && $WEBHOOK_SECRET_SET && $ORGANIZATION_SET && $WEBHOOK_URL_SET && $AI_REVIEW_LANGUAGE_SET; then
    echo -e "${GREEN}🎉 모든 환경변수가 이미 설정되어 있습니다!${NC}"
    echo ""
    echo "현재 설정값:"
    echo "- GitHub Token: ${GITHUB_WEBHOOK_TOKEN:0:8}... (처음 8자리만 표시)"
    echo "- Webhook Secret: ${GITHUB_WEBHOOK_SECRET:0:8}... (처음 8자리만 표시)"
    echo "- Organization: $ORGANIZATION_NAME"
    echo "- Webhook URL: $WEBHOOK_URL"
    echo "- Review Language: $AI_REVIEW_LANGUAGE"
    echo ""
    read -p "환경변수를 다시 설정하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    echo ""
fi

echo -e "${YELLOW}⚡ 대화형 환경변수 설정을 시작합니다${NC}"
echo "============================================"
echo "각 항목에 대해 값을 입력하거나 Enter를 눌러 스킵할 수 있습니다."
echo ""

# GitHub Token 설정
echo -e "${BLUE}1. GitHub Personal Access Token${NC}"
echo "================================================"
echo ""
echo -e "${CYAN}📝 GitHub Token이 필요한 이유:${NC}"
echo "- Organization의 웹훅 설정/조회"
echo "- PR 댓글 작성 및 코드 수정"
echo "- Repository 접근 및 분석"
echo ""

# GitHub Token 생성 URL with pre-selected scopes (전역으로 정의)
TOKEN_URL="https://github.com/settings/tokens/new?scopes=repo,read:org,write:org,admin:org_hook&description=GitHub%20Organization%20AI%20Review%20System"

if ! $GITHUB_WEBHOOK_TOKEN_SET; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}🔗 GitHub Token 자동 생성 링크 (클릭하세요!)${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${GREEN}👆 아래 링크를 복사해서 브라우저에 붙여넣으세요:${NC}"
    echo -e "${CYAN}$TOKEN_URL${NC}"
    echo ""
    echo -e "${GREEN}✨ 이 링크의 장점:${NC}"
    echo "  - 필요한 권한이 미리 선택됨 (repo, read:org, write:org, admin:org_hook)"
    echo "  - 토큰 설명도 자동으로 입력됨"
    echo "  - 바로 토큰 생성 가능"
    echo ""
    
    echo "💡 GitHub Token 입력 방법을 선택하세요:"
    echo "1. 안전하게 입력 (화면에 보이지 않음) - 권장"
    echo "2. 화면에 보이게 입력 (디버깅용)"
    echo ""
    
    while true; do
        read -p "선택 (1/2, Enter=1): " input_method
        
        # Enter만 눌렀거나 1을 선택한 경우
        if [ -z "$input_method" ] || [ "$input_method" = "1" ]; then
            echo "🔑 GitHub Token을 입력하세요 (입력 내용이 보이지 않습니다)"
            read -p "입력 (스킵하려면 Enter): " -s github_token
            break
        elif [ "$input_method" = "2" ]; then
            read -p "🔑 GitHub Token 입력 (스킵하려면 Enter): " github_token
            break
        else
            echo -e "${RED}❌ 올바른 선택이 아닙니다. 1 또는 2를 입력하세요.${NC}"
        fi
    done
    echo ""
    
    if [ -n "$github_token" ]; then
        # 토큰 유효성 간단 검증
        if [[ $github_token =~ ^gh[ps]_[a-zA-Z0-9]{36,}$ ]]; then
            NEW_GITHUB_WEBHOOK_TOKEN="$github_token"
            echo -e "${GREEN}✅ GitHub Token이 설정되었습니다${NC}"
        else
            echo -e "${YELLOW}⚠️  입력하신 토큰 형식이 올바르지 않을 수 있습니다. 계속 진행합니다.${NC}"
            NEW_GITHUB_WEBHOOK_TOKEN="$github_token"
        fi
    else
        echo -e "${YELLOW}⏭️  GitHub Token 설정을 스킵했습니다${NC}"
    fi
else
    echo -e "${GREEN}현재 설정된 토큰: ${GITHUB_WEBHOOK_TOKEN:0:8}...${NC}"
    read -p "새로운 토큰으로 교체하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${YELLOW}🔗 GitHub Token 자동 생성 링크 (클릭하세요!)${NC}"
        echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo -e "${GREEN}👆 아래 링크를 복사해서 브라우저에 붙여넣으세요:${NC}"
        echo -e "${CYAN}$TOKEN_URL${NC}"
        echo ""
        echo "💡 새로운 GitHub Token 입력 방법을 선택하세요:"
        echo "1. 안전하게 입력 (화면에 보이지 않음) - 권장"
        echo "2. 화면에 보이게 입력 (디버깅용)"
        echo ""
        
        while true; do
            read -p "선택 (1/2, Enter=1): " input_method
            
            # Enter만 눌렀거나 1을 선택한 경우
            if [ -z "$input_method" ] || [ "$input_method" = "1" ]; then
                echo "🔑 새로운 GitHub Token을 입력하세요 (입력 내용이 보이지 않습니다)"
                read -p "입력: " -s github_token
                break
            elif [ "$input_method" = "2" ]; then
                read -p "🔑 새로운 GitHub Token 입력: " github_token
                break
            else
                echo -e "${RED}❌ 올바른 선택이 아닙니다. 1 또는 2를 입력하세요.${NC}"
            fi
        done
        echo ""
        if [ -n "$github_token" ]; then
            NEW_GITHUB_WEBHOOK_TOKEN="$github_token"
            echo -e "${GREEN}✅ GitHub Token이 업데이트되었습니다${NC}"
        fi
    else
        NEW_GITHUB_WEBHOOK_TOKEN="$GITHUB_WEBHOOK_TOKEN"
    fi
fi

echo ""

# Webhook Secret 설정
echo -e "${BLUE}2. GitHub Webhook Secret${NC}"
echo "==============================================="
echo ""
echo -e "${CYAN}📝 Webhook Secret이란?${NC}"
echo "- GitHub 웹훅의 보안을 위한 비밀 키입니다"
echo "- 임의의 문자열을 사용하면 됩니다 (20자 이상 권장)"
echo "- GitHub에서 웹훅 요청이 올 때 이 키로 검증합니다"
echo ""
echo -e "${YELLOW}💡 Webhook Secret 생성 가이드:${NC}"
echo "- 20자 이상의 랜덤 문자열 (영문, 숫자, 특수문자)"
echo "- 예: myorg-ai-review-webhook-$(date +%Y%m%d)-secret"
echo "- 예: $(openssl rand -hex 16) (랜덤 생성)"
echo ""

if ! $WEBHOOK_SECRET_SET; then
    # 기본값 제안
    DEFAULT_SECRET="ai-review-webhook-$(date +%Y%m%d)-$(openssl rand -hex 8)"
    echo -e "${CYAN}🎲 자동 생성된 추천값: $DEFAULT_SECRET${NC}"
    echo ""
    
    while true; do
        read -p "Webhook Secret을 입력하세요 (Enter시 추천값 사용, 's'로 스킵): " webhook_secret
        
        if [ -z "$webhook_secret" ]; then
            NEW_WEBHOOK_SECRET="$DEFAULT_SECRET"
            echo -e "${GREEN}✅ 추천 Webhook Secret이 설정되었습니다${NC}"
            break
        elif [ "$webhook_secret" = "s" ] || [ "$webhook_secret" = "S" ]; then
            echo -e "${YELLOW}⏭️  Webhook Secret 설정을 스킵했습니다${NC}"
            break
        else
            # 최소 길이 검증 (20자 이상 권장)
            if [ ${#webhook_secret} -lt 20 ]; then
                echo -e "${YELLOW}⚠️  보안을 위해 20자 이상의 Secret을 권장합니다.${NC}"
                read -p "그래도 사용하시겠습니까? (y/N): " -n 1 -r
                echo ""
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    NEW_WEBHOOK_SECRET="$webhook_secret"
                    echo -e "${GREEN}✅ Webhook Secret이 설정되었습니다${NC}"
                    break
                else
                    echo "다시 입력해주세요."
                fi
            else
                NEW_WEBHOOK_SECRET="$webhook_secret"
                echo -e "${GREEN}✅ Webhook Secret이 설정되었습니다${NC}"
                break
            fi
        fi
    done
else
    echo -e "${GREEN}현재 설정된 Secret: ${GITHUB_WEBHOOK_SECRET:0:8}...${NC}"
    read -p "새로운 Secret으로 교체하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        DEFAULT_SECRET="ai-review-webhook-$(date +%Y%m%d)-$(openssl rand -hex 8)"
        echo ""
        echo -e "${CYAN}🎲 새로운 추천값: $DEFAULT_SECRET${NC}"
        echo ""
        read -p "새로운 Webhook Secret을 입력하세요 (Enter시 추천값 사용): " webhook_secret
        
        if [ -z "$webhook_secret" ]; then
            NEW_WEBHOOK_SECRET="$DEFAULT_SECRET"
        else
            NEW_WEBHOOK_SECRET="$webhook_secret"
        fi
        echo -e "${GREEN}✅ Webhook Secret이 업데이트되었습니다${NC}"
    else
        NEW_WEBHOOK_SECRET="$GITHUB_WEBHOOK_SECRET"
    fi
fi

echo ""

# Organization Name 설정
echo -e "${BLUE}3. GitHub Organization Name${NC}"
echo "==========================================="
echo ""
echo -e "${CYAN}📝 Organization Name이란?${NC}"
echo "- GitHub Organization의 이름입니다"
echo "- URL에서 확인: https://github.com/YOUR_ORG_NAME"
echo "- 예: 'microsoft', 'facebook', 'google' 등"
echo ""

if ! $ORGANIZATION_SET; then
    read -p "GitHub Organization 이름을 입력하세요 (스킵하려면 Enter): " org_name
    
    if [ -n "$org_name" ]; then
        NEW_ORGANIZATION_NAME="$org_name"
        echo -e "${GREEN}✅ Organization 이름이 설정되었습니다${NC}"
    else
        echo -e "${YELLOW}⏭️  Organization 이름 설정을 스킵했습니다${NC}"
    fi
else
    echo -e "${GREEN}현재 설정된 Organization: $ORGANIZATION_NAME${NC}"
    read -p "새로운 Organization으로 교체하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        read -p "새로운 Organization 이름을 입력하세요: " org_name
        if [ -n "$org_name" ]; then
            NEW_ORGANIZATION_NAME="$org_name"
            echo -e "${GREEN}✅ Organization 이름이 업데이트되었습니다${NC}"
        else
            NEW_ORGANIZATION_NAME="$ORGANIZATION_NAME"
        fi
    else
        NEW_ORGANIZATION_NAME="$ORGANIZATION_NAME"
    fi
fi

echo ""

# Webhook URL 설정
echo -e "${BLUE}4. Webhook URL (Cloudflare Tunnel)${NC}"
echo "========================================="
echo ""
echo -e "${CYAN}📝 Webhook URL이란?${NC}"
echo "- GitHub 웹훅이 호출할 외부 접근 가능한 URL입니다"
echo "- Cloudflare Tunnel을 통해 노출된 엔드포인트를 입력하세요"
echo "- 형식: https://your-tunnel-domain.com/webhook"
echo ""
echo -e "${YELLOW}💡 Cloudflare Tunnel URL 확인 방법:${NC}"
echo "- Cloudflare Dashboard → Zero Trust → Access → Tunnels"
echo "- 또는 'cloudflared tunnel list' 명령어로 확인"
echo "- URL 끝에 '/webhook' 경로를 추가해야 합니다"
echo ""

if ! $WEBHOOK_URL_SET; then
    read -p "Webhook URL을 입력하세요 (예: https://your-domain.com/webhook, 스킵하려면 Enter): " webhook_url
    
    if [ -n "$webhook_url" ]; then
        # URL 형식 간단 검증
        if [[ $webhook_url =~ ^https?:// ]]; then
            # /webhook 경로가 없으면 추가
            if [[ ! $webhook_url =~ /webhook$ ]]; then
                webhook_url="${webhook_url}/webhook"
                echo -e "${YELLOW}⚠️  '/webhook' 경로가 자동으로 추가되었습니다: $webhook_url${NC}"
            fi
            NEW_WEBHOOK_URL="$webhook_url"
            echo -e "${GREEN}✅ Webhook URL이 설정되었습니다${NC}"
        else
            echo -e "${YELLOW}⚠️  올바른 URL 형식이 아닙니다 (http:// 또는 https://로 시작해야 함)${NC}"
            echo -e "${YELLOW}입력하신 URL을 그대로 사용합니다: $webhook_url${NC}"
            NEW_WEBHOOK_URL="$webhook_url"
        fi
    else
        echo -e "${YELLOW}⏭️  Webhook URL 설정을 스킵했습니다${NC}"
    fi
else
    echo -e "${GREEN}현재 설정된 Webhook URL: $WEBHOOK_URL${NC}"
    read -p "새로운 URL로 교체하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        read -p "새로운 Webhook URL을 입력하세요: " webhook_url
        if [ -n "$webhook_url" ]; then
            if [[ $webhook_url =~ ^https?:// ]]; then
                if [[ ! $webhook_url =~ /webhook$ ]]; then
                    webhook_url="${webhook_url}/webhook"
                    echo -e "${YELLOW}⚠️  '/webhook' 경로가 자동으로 추가되었습니다: $webhook_url${NC}"
                fi
                NEW_WEBHOOK_URL="$webhook_url"
                echo -e "${GREEN}✅ Webhook URL이 업데이트되었습니다${NC}"
            else
                echo -e "${YELLOW}⚠️  올바른 URL 형식이 아닙니다만 그대로 사용합니다: $webhook_url${NC}"
                NEW_WEBHOOK_URL="$webhook_url"
            fi
        else
            NEW_WEBHOOK_URL="$WEBHOOK_URL"
        fi
    else
        NEW_WEBHOOK_URL="$WEBHOOK_URL"
    fi
fi

echo ""

# AI Review Language 설정
echo -e "${BLUE}5. AI Review Language (리뷰 언어)${NC}"
echo "========================================="
echo ""
echo -e "${CYAN}📝 AI Review Language란?${NC}"
echo "- AI가 코드 리뷰를 작성할 때 사용할 언어입니다"
echo "- PR 댓글, 커밋 메시지 등이 이 언어로 작성됩니다"
echo "- 기본값: english (영어)"
echo ""
echo -e "${YELLOW}💡 지원되는 언어:${NC}"
echo "- english (영어) - 기본값"
echo "- korean (한국어)"
echo "- japanese (일본어)" 
echo "- chinese (중국어)"
echo "- spanish (스페인어)"
echo "- french (프랑스어)"
echo ""

if ! $AI_REVIEW_LANGUAGE_SET; then
    # 기본값 제안
    DEFAULT_LANGUAGE="english"
    echo -e "${CYAN}🌐 권장 기본값: $DEFAULT_LANGUAGE${NC}"
    echo ""
    
    while true; do
        read -p "AI Review Language을 입력하세요 (Enter시 기본값 사용, 예: korean, japanese): " review_language
        
        if [ -z "$review_language" ]; then
            NEW_AI_REVIEW_LANGUAGE="$DEFAULT_LANGUAGE"
            echo -e "${GREEN}✅ 기본 리뷰 언어(english)가 설정되었습니다${NC}"
            break
        else
            # 입력값을 소문자로 변환
            review_language=$(echo "$review_language" | tr '[:upper:]' '[:lower:]')
            
            # 지원되는 언어 목록
            case "$review_language" in
                "english"|"en"|"영어")
                    NEW_AI_REVIEW_LANGUAGE="english"
                    echo -e "${GREEN}✅ 리뷰 언어가 English로 설정되었습니다${NC}"
                    break
                    ;;
                "korean"|"ko"|"kr"|"한국어"|"kor")
                    NEW_AI_REVIEW_LANGUAGE="korean"
                    echo -e "${GREEN}✅ 리뷰 언어가 Korean으로 설정되었습니다${NC}"
                    break
                    ;;
                "japanese"|"jp"|"ja"|"일본어"|"jpn")
                    NEW_AI_REVIEW_LANGUAGE="japanese"
                    echo -e "${GREEN}✅ 리뷰 언어가 Japanese로 설정되었습니다${NC}"
                    break
                    ;;
                "chinese"|"cn"|"zh"|"중국어"|"chn")
                    NEW_AI_REVIEW_LANGUAGE="chinese"
                    echo -e "${GREEN}✅ 리뷰 언어가 Chinese로 설정되었습니다${NC}"
                    break
                    ;;
                "spanish"|"es"|"esp"|"스페인어")
                    NEW_AI_REVIEW_LANGUAGE="spanish"
                    echo -e "${GREEN}✅ 리뷰 언어가 Spanish로 설정되었습니다${NC}"
                    break
                    ;;
                "french"|"fr"|"fra"|"프랑스어")
                    NEW_AI_REVIEW_LANGUAGE="french"
                    echo -e "${GREEN}✅ 리뷰 언어가 French로 설정되었습니다${NC}"
                    break
                    ;;
                *)
                    echo -e "${YELLOW}⚠️  '$review_language'는 지원되지 않는 언어입니다.${NC}"
                    echo "지원되는 언어: english, korean, japanese, chinese, spanish, french"
                    read -p "그래도 사용하시겠습니까? (y/N): " -n 1 -r
                    echo ""
                    if [[ $REPLY =~ ^[Yy]$ ]]; then
                        NEW_AI_REVIEW_LANGUAGE="$review_language"
                        echo -e "${GREEN}✅ 커스텀 리뷰 언어($review_language)가 설정되었습니다${NC}"
                        break
                    else
                        echo "다시 입력해주세요."
                    fi
                    ;;
            esac
        fi
    done
else
    echo -e "${GREEN}현재 설정된 Review Language: $AI_REVIEW_LANGUAGE${NC}"
    read -p "새로운 언어로 교체하시겠습니까? (y/N): " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo -e "${CYAN}🌐 새로운 언어를 선택하세요:${NC}"
        echo "- english (영어) - 기본값"
        echo "- korean (한국어)"
        echo "- japanese (일본어)" 
        echo "- chinese (중국어)"
        echo ""
        read -p "새로운 AI Review Language을 입력하세요: " review_language
        
        if [ -n "$review_language" ]; then
            review_language=$(echo "$review_language" | tr '[:upper:]' '[:lower:]')
            case "$review_language" in
                "english"|"en") NEW_AI_REVIEW_LANGUAGE="english" ;;
                "korean"|"ko"|"kr"|"한국어") NEW_AI_REVIEW_LANGUAGE="korean" ;;
                "japanese"|"jp"|"ja"|"일본어") NEW_AI_REVIEW_LANGUAGE="japanese" ;;
                "chinese"|"cn"|"zh"|"중국어") NEW_AI_REVIEW_LANGUAGE="chinese" ;;
                "spanish"|"es") NEW_AI_REVIEW_LANGUAGE="spanish" ;;
                "french"|"fr") NEW_AI_REVIEW_LANGUAGE="french" ;;
                *) NEW_AI_REVIEW_LANGUAGE="$review_language" ;;
            esac
            echo -e "${GREEN}✅ AI Review Language가 업데이트되었습니다: $NEW_AI_REVIEW_LANGUAGE${NC}"
        else
            NEW_AI_REVIEW_LANGUAGE="$AI_REVIEW_LANGUAGE"
        fi
    else
        NEW_AI_REVIEW_LANGUAGE="$AI_REVIEW_LANGUAGE"
    fi
fi

echo ""

# 설정 요약 및 확인
echo -e "${CYAN}📋 설정 요약${NC}"
echo "============"

HAS_UPDATES=false

if [ -n "$NEW_GITHUB_WEBHOOK_TOKEN" ]; then
    echo "- GitHub Token: ${NEW_GITHUB_WEBHOOK_TOKEN:0:8}... (설정됨)"
    HAS_UPDATES=true
else
    echo "- GitHub Token: 설정 안함"
fi

if [ -n "$NEW_WEBHOOK_SECRET" ]; then
    echo "- Webhook Secret: ${NEW_WEBHOOK_SECRET:0:8}... (설정됨)"
    HAS_UPDATES=true
else
    echo "- Webhook Secret: 설정 안함"
fi

if [ -n "$NEW_ORGANIZATION_NAME" ]; then
    echo "- Organization: $NEW_ORGANIZATION_NAME (설정됨)"
    HAS_UPDATES=true
else
    echo "- Organization: 설정 안함"
fi

if [ -n "$NEW_WEBHOOK_URL" ]; then
    echo "- Webhook URL: $NEW_WEBHOOK_URL (설정됨)"
    HAS_UPDATES=true
else
    echo "- Webhook URL: 설정 안함"
fi

if [ -n "$NEW_AI_REVIEW_LANGUAGE" ]; then
    echo "- Review Language: $NEW_AI_REVIEW_LANGUAGE (설정됨)"
    HAS_UPDATES=true
else
    echo "- Review Language: 설정 안함 (기본값: english)"
fi

echo ""

if ! $HAS_UPDATES; then
    echo -e "${YELLOW}⚠️  설정할 새로운 환경변수가 없습니다.${NC}"
    exit 0
fi

while true; do
    read -p "이 설정을 ~/.bashrc에 저장하시겠습니까? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        break  # y를 선택한 경우 저장 진행
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}설정 저장이 취소되었습니다.${NC}"
        exit 0
    else
        echo -e "${RED}❌ 올바른 선택이 아닙니다. y 또는 n을 입력하세요.${NC}"
    fi
done

# ~/.bashrc 백업
cp ~/.bashrc ~/.bashrc.backup.$(date +%Y%m%d_%H%M%S)
echo -e "${GREEN}✅ ~/.bashrc 백업 완료${NC}"

# 기존 환경변수 제거 (있다면)
sed -i '/# GitHub Organization AI Review System/d' ~/.bashrc
sed -i '/export GITHUB_WEBHOOK_TOKEN=/d' ~/.bashrc
sed -i '/export GITHUB_WEBHOOK_SECRET=/d' ~/.bashrc
sed -i '/export ORGANIZATION_NAME=/d' ~/.bashrc
sed -i '/export WEBHOOK_URL=/d' ~/.bashrc
sed -i '/export AI_REVIEW_LANGUAGE=/d' ~/.bashrc

# 새로운 환경변수 추가
echo "" >> ~/.bashrc
echo "# GitHub Organization AI Review System" >> ~/.bashrc

if [ -n "$NEW_GITHUB_WEBHOOK_TOKEN" ]; then
    echo "export GITHUB_WEBHOOK_TOKEN=\"$NEW_GITHUB_WEBHOOK_TOKEN\"" >> ~/.bashrc
fi

if [ -n "$NEW_WEBHOOK_SECRET" ]; then
    echo "export GITHUB_WEBHOOK_SECRET=\"$NEW_WEBHOOK_SECRET\"" >> ~/.bashrc
fi

if [ -n "$NEW_ORGANIZATION_NAME" ]; then
    echo "export ORGANIZATION_NAME=\"$NEW_ORGANIZATION_NAME\"" >> ~/.bashrc
fi

if [ -n "$NEW_WEBHOOK_URL" ]; then
    echo "export WEBHOOK_URL=\"$NEW_WEBHOOK_URL\"" >> ~/.bashrc
fi

if [ -n "$NEW_AI_REVIEW_LANGUAGE" ]; then
    echo "export AI_REVIEW_LANGUAGE=\"$NEW_AI_REVIEW_LANGUAGE\"" >> ~/.bashrc
fi

echo ""
echo -e "${GREEN}🎉 환경변수가 성공적으로 ~/.bashrc에 저장되었습니다!${NC}"
echo ""
printf "\n%b📌 다음 단계:%b\n" "$YELLOW" "$NC"
printf "1. 환경변수 적용: %bsource ~/.bashrc%b\n" "$CYAN" "$NC"
printf "2. 시스템 테스트: %b./scripts/test-system.sh%b\n" "$CYAN" "$NC"
printf "3. 서버 시작: %b./scripts/start-webhook-server.sh%b\n" "$CYAN" "$NC"
echo ""

# 자동으로 환경변수 적용할지 묻기
while true; do
    read -p "지금 바로 환경변수를 적용하시겠습니까? (y/n, Enter=y): " -n 1 -r
    echo ""
    
    if [[ -z "$REPLY" ]] || [[ $REPLY =~ ^[Yy]$ ]]; then
        source ~/.bashrc
        echo -e "${GREEN}✅ 환경변수가 적용되었습니다!${NC}"
        break
    elif [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}⚠️  환경변수를 적용하려면 'source ~/.bashrc'를 실행하세요.${NC}"
        exit 0
    else
        echo -e "${RED}❌ 올바른 선택이 아닙니다. y 또는 n을 입력하세요.${NC}"
    fi
done

echo ""

# 적용 확인
echo -e "${BLUE}🔍 환경변수 적용 확인:${NC}"

if [ -n "$GITHUB_WEBHOOK_TOKEN" ]; then
    echo -e "✅ ${GREEN}GITHUB_WEBHOOK_TOKEN: 적용됨${NC}"
else
    echo -e "❌ ${RED}GITHUB_WEBHOOK_TOKEN: 적용 안됨${NC}"
fi

if [ -n "$GITHUB_WEBHOOK_SECRET" ]; then
    echo -e "✅ ${GREEN}GITHUB_WEBHOOK_SECRET: 적용됨${NC}"
else
    echo -e "❌ ${RED}GITHUB_WEBHOOK_SECRET: 적용 안됨${NC}"
fi

if [ -n "$ORGANIZATION_NAME" ]; then
    echo -e "✅ ${GREEN}ORGANIZATION_NAME: 적용됨 ($ORGANIZATION_NAME)${NC}"
else
    echo -e "❌ ${RED}ORGANIZATION_NAME: 적용 안됨${NC}"
fi

if [ -n "$WEBHOOK_URL" ]; then
    echo -e "✅ ${GREEN}WEBHOOK_URL: 적용됨 ($WEBHOOK_URL)${NC}"
else
    echo -e "❌ ${RED}WEBHOOK_URL: 적용 안됨${NC}"
fi

if [ -n "$AI_REVIEW_LANGUAGE" ]; then
    echo -e "✅ ${GREEN}AI_REVIEW_LANGUAGE: 적용됨 ($AI_REVIEW_LANGUAGE)${NC}"
else
    echo -e "❌ ${RED}AI_REVIEW_LANGUAGE: 적용 안됨${NC}"
fi

echo ""
printf "%b🚀 이제 './scripts/test-system.sh'를 실행하여 시스템을 테스트할 수 있습니다!%b\n" "$CYAN" "$NC"