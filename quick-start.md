# 🚀 빠른 시작 가이드

## 1. 프로젝트 디렉토리로 이동

```bash
cd ~/github-ai-review-system
```

## 2. 환경변수 설정 (3개만 필요)

```bash
# 설정 가이드 확인
./scripts/setup-env-simple.sh

# ~/.bashrc 파일 수정
nano ~/.bashrc

# 파일 끝에 다음 3줄 추가:
export GITHUB_WEBHOOK_TOKEN="your_github_token_here"
export GITHUB_WEBHOOK_SECRET="your_webhook_secret_here"  
export ORGANIZATION_NAME="your_organization_name"

# 저장 후 적용
source ~/.bashrc
```

### GitHub Token 생성 방법:
1. https://github.com/settings/tokens/new 접속
2. `repo` (모든 하위 항목 선택)
3. `admin:org` → `read:org`, `write:org` 선택
4. Generate token

## 3. 전체 시스템 테스트

```bash
./scripts/test-system.sh
```

이 명령어가 모든 검증을 자동으로 수행합니다:
- ✅ 환경변수 확인
- ✅ GitHub CLI 인증
- ✅ Organization 권한
- ✅ Claude SubAgent들
- ✅ 웹훅 자동 설정
- ✅ Node.js 의존성 설치
- ✅ 로그 디렉토리 준비

## 4. 서버 시작

```bash
./scripts/start-webhook-server.sh
```

## 5. 실제 테스트

### 자동 테스트 (권장):
```bash
# Organization의 아무 저장소에서
cd /tmp
gh repo clone your_org/your_repo
cd your_repo
git checkout -b test-ai-review-$(date +%s)
echo "# AI Review Test" > test-file.md
git add test-file.md
git commit -m "test: AI review system"
git push origin HEAD
gh pr create --title "[TEST] AI Review System" --body "Testing AI review"
```

### 수동 테스트:
PR 댓글에 `@claude-bot review` 입력

## 6. 결과 확인

### 로그 실시간 확인:
```bash
tail -f ~/github-ai-review-system/logs/webhook-server.log
```

### 통계 확인:
```bash
./scripts/org-review-stats.sh $ORGANIZATION_NAME 1
```

### 서버 상태:
```bash
curl http://localhost:3000/health
curl http://localhost:3000/status
```

## 🎯 기대 결과

1. **PR 생성시**: 4개 SubAgent가 자동 리뷰
2. **5-10분 후**: GitHub PR에 AI 리뷰 댓글 등록
3. **안전한 수정**: 자동 커밋 적용 (있는 경우)
4. **로그 기록**: `~/github-ai-review-system/logs/webhook-server.log`에 모든 과정 기록

## ❗ 문제해결

### 웹훅 오류:
```bash
./scripts/check-org-webhook.sh $ORGANIZATION_NAME
```

### Agent 오류:
```bash
claude --agent security-reviewer --help
```

### GitHub 권한 오류:
```bash
gh auth login
```

### 환경변수 미설정:
```bash
./scripts/setup-env-simple.sh
```

---

**중요**: 
- Claude API 키는 불필요합니다 (이미 인증된 Claude Code 사용)
- Organization owner 권한이 있는 GitHub 계정 필요
- 모든 파일이 `~/github-ai-review-system/` 디렉토리에 정리되어 있음