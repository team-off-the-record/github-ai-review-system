# 🔍 AI 리뷰 시스템 상태 확인 가이드

## ✅ 현재 상태 (2025-08-09T16:35:00Z)

### 성공적으로 작동하는 기능:
- ✅ **웹훅 수신**: GitHub → Cloudflare Tunnel → 로컬 서버
- ✅ **리뷰 트리거**: `@claude-bot review` 댓글 인식
- ✅ **Repository 클론**: 자동으로 PR 코드 다운로드
- ✅ **3/4 SubAgent 완료**: UX, Architecture, Performance
- ✅ **GitHub 댓글 게시**: AI 리뷰 결과 자동 업로드

### 개선 필요 사항:
- ⚠️ **Security 리뷰어 타임아웃**: 5분 초과로 실패
- ⚠️ **SubAgent 출력 오류**: "Execution error" 표시
- ❌ **ANTHROPIC_API_KEY 없음**: Claude API 접근 불가

## 🔍 상태 확인 명령어들

### 1. 실시간 모니터링
```bash
# 실시간 로그 확인 (Ctrl+C로 종료)
journalctl --user -u claude-webhook -f

# 파일 로그 실시간 확인
tail -f ~/github-ai-review-system/claude-webhook-server/logs/combined.log
```

### 2. GitHub PR 댓글 확인
```bash
# 댓글 개수 확인
gh pr view 1 --repo team-off-the-record/off-the-record-server --json comments --jq '.comments | length'

# 최신 AI 댓글 내용 확인
gh api repos/team-off-the-record/off-the-record-server/issues/comments --jq '.[-1].body'

# PR 전체 댓글 확인 
gh pr view 1 --repo team-off-the-record/off-the-record-server --comments
```

### 3. 시스템 건강 상태
```bash
# 종합 건강 체크 (권장)
~/github-ai-review-system/webhook-health-monitor.sh

# 조직 통계 확인
~/github-ai-review-system/org-review-stats.sh team-off-the-record
```

### 4. 로그 분석
```bash
# 성공한 리뷰어 확인
grep "completed successfully" ~/github-ai-review-system/claude-webhook-server/logs/combined.log

# 실패한 리뷰어 확인
grep "failed\|error" ~/github-ai-review-system/claude-webhook-server/logs/combined.log

# 최근 10개 이벤트
tail -10 ~/github-ai-review-system/claude-webhook-server/logs/combined.log
```

### 5. 프로세스 상태 확인
```bash
# Claude 프로세스 확인 (리뷰 중이면 여러 개 표시)
ps aux | grep claude | grep -v grep

# 웹훅 서버 상태
systemctl --user status claude-webhook

# 메모리 사용량
systemctl --user show claude-webhook --property=MainPID,MemoryCurrent
```

### 6. GitHub 웹훅 상태
```bash
# 웹훅 전송 성공률 확인
gh api orgs/team-off-the-record/hooks/562953431/deliveries \
  --jq '.[0:10] | map(select(.status_code == 200)) | length'

# 최근 웹훅 전송 현황
gh api orgs/team-off-the-record/hooks/562953431/deliveries \
  --jq '.[0:5] | .[] | "Event: \(.event) | Status: \(.status) | Code: \(.status_code) | Time: \(.delivered_at)"'
```

## 🚨 오류 유형별 해결 방법

### SubAgent 타임아웃 (5분 초과)
```bash
# 타임아웃 시간 조정이 필요하거나 Claude API 키 설정 필요
# 웹훅 서버 재시작
systemctl --user restart claude-webhook
```

### "Execution error" 표시
```bash
# ANTHROPIC_API_KEY 설정 필요
echo 'ANTHROPIC_API_KEY=your_key_here' >> ~/github-ai-review-system/claude-webhook-server/.env
systemctl --user restart claude-webhook
```

### GitHub 댓글 게시 실패
```bash
# GitHub 토큰 권한 확인
gh auth status

# 토큰 권한이 부족하면 재인증
gh auth refresh -s write:org
```

### 웹훅 수신 실패
```bash
# 터널 상태 확인
curl https://webhook.yeonsik.kim/health

# 터널 재시작이 필요하면 Cloudflare 대시보드에서 확인
```

## 📊 성공 지표

### ✅ 정상 작동 시 보이는 로그:
```
{"level":"info","message":"Manual review triggered by comment"}
{"level":"info","message":"Repository cloned successfully"}
{"level":"info","message":"Starting parallel reviews with 4 agents"}
{"level":"info","message":"[agent-name] completed successfully"}
{"level":"info","message":"Integration completed successfully"}
{"level":"info","message":"Review comment posted successfully"}
```

### ✅ GitHub PR에 나타나는 댓글:
- 🤖 AI Code Review Summary
- 각 SubAgent별 리뷰 결과
- 통합 분석 결과
- Claude Code 생성 표시

## 🔄 테스트 명령어

### 수동 리뷰 트리거
```bash
# PR에 새 댓글로 리뷰 트리거
gh pr comment 1 --repo team-off-the-record/off-the-record-server \
  --body "@claude-bot review - Manual test $(date)"

# 또는 스크립트 사용
~/github-ai-review-system/manual-trigger-review.sh team-off-the-record/off-the-record-server 1
```

### 시스템 전체 테스트
```bash
# 건강 상태 확인 → 리뷰 트리거 → 결과 확인
~/github-ai-review-system/webhook-health-monitor.sh && \
gh pr comment 1 --repo team-off-the-record/off-the-record-server --body "@claude-bot review" && \
sleep 300 && \
gh pr view 1 --repo team-off-the-record/off-the-record-server --comments
```

---
*Updated: 2025-08-09T16:35:00Z*