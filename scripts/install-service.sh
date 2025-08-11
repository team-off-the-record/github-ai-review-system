#!/bin/bash
# GitHub AI Review System 서비스 설치 스크립트

set -e

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}🚀 GitHub AI Review System 서비스 설치${NC}"
echo "========================================================"

# 현재 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "프로젝트 디렉토리: $PROJECT_DIR"

# 기존 서비스 중지 (있다면)
if systemctl is-active --quiet github-ai-review; then
    echo -e "${YELLOW}⚠️ 기존 서비스를 중지합니다...${NC}"
    sudo systemctl stop github-ai-review
fi

# 서비스 파일 복사
echo -e "${BLUE}📂 서비스 파일을 시스템에 설치합니다...${NC}"
sudo cp "$PROJECT_DIR/scripts/github-ai-review.service" /etc/systemd/system/

# 서비스 파일에서 사용자 및 디렉토리 경로 업데이트
sudo sed -i "s|User=y30n51k|User=$USER|g" /etc/systemd/system/github-ai-review.service
sudo sed -i "s|WorkingDirectory=/home/y30n51k/github-ai-review-system|WorkingDirectory=$PROJECT_DIR|g" /etc/systemd/system/github-ai-review.service
sudo sed -i "s|ReadWritePaths=/home/y30n51k/github-ai-review-system|ReadWritePaths=$PROJECT_DIR|g" /etc/systemd/system/github-ai-review.service

# systemd 리로드
echo -e "${BLUE}🔄 systemd 설정을 다시 로드합니다...${NC}"
sudo systemctl daemon-reload

# 서비스 활성화 (재부팅 시 자동 시작)
echo -e "${BLUE}✅ 서비스를 활성화합니다 (재부팅 시 자동 시작)...${NC}"
sudo systemctl enable github-ai-review

# 서비스 시작
echo -e "${GREEN}🚀 서비스를 시작합니다...${NC}"
sudo systemctl start github-ai-review

# 상태 확인
echo ""
echo -e "${CYAN}📊 서비스 상태:${NC}"
sudo systemctl status github-ai-review --no-pager -l

echo ""
echo -e "${GREEN}✅ 설치가 완료되었습니다!${NC}"
echo ""
echo -e "${YELLOW}📌 유용한 명령어들:${NC}"
echo "- 서비스 상태 확인:    ${CYAN}sudo systemctl status github-ai-review${NC}"
echo "- 서비스 중지:         ${CYAN}sudo systemctl stop github-ai-review${NC}"
echo "- 서비스 시작:         ${CYAN}sudo systemctl start github-ai-review${NC}"
echo "- 서비스 재시작:       ${CYAN}sudo systemctl restart github-ai-review${NC}"
echo "- 로그 확인:           ${CYAN}sudo journalctl -u github-ai-review -f${NC}"
echo "- 자동시작 비활성화:   ${CYAN}sudo systemctl disable github-ai-review${NC}"
echo ""
echo -e "${BLUE}🌐 서버 엔드포인트: http://localhost:3000${NC}"