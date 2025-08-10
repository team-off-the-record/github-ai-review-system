# 🔧 Cloudflare Tunnel 문제 진단 및 해결 방법

## 📊 현재 상태

### ✅ 정상 작동 중
- **터널 연결**: Cloudflare Edge 서버에 정상 연결됨
- **터널 ID**: e00b68ad-aaac-4fa6-be5d-af54def58a21
- **연결 상태**: 2xicn01, 2xicn06 (활성)
- **로컬 서버**: localhost:3000에서 정상 응답

### ❌ 문제점
- **Ingress 규칙 없음**: 토큰 기반 실행으로 트래픽 라우팅 규칙이 설정되지 않음
- **503 에러**: 모든 HTTP 요청에 대해 503 Service Unavailable 반환
- **외부 접근 불가**: https://webhook.yeonsik.com 접근 실패

## 🔍 문제 원인

현재 cloudflared가 다음 명령으로 실행되고 있음:
```bash
/usr/bin/cloudflared --no-autoupdate tunnel run --token [TOKEN]
```

이 방식은 **ingress 규칙을 설정하지 않으므로** 모든 요청이 503 에러를 반환합니다.

## 🛠️ 해결 방법

### 방법 1: Cloudflare Dashboard에서 설정 (권장)

1. **Cloudflare Zero Trust Dashboard 접속**
   - https://dash.cloudflare.com → Zero Trust → Access → Tunnels

2. **webhook 터널 선택**
   - "webhook" 터널 찾기 → "Configure" 클릭

3. **Public Hostname 추가**
   ```
   Subdomain: webhook
   Domain: yeonsik.com  
   Service Type: HTTP
   URL: localhost:3000
   ```

4. **저장 및 확인**
   - "Save tunnel" 클릭
   - 5-10분 후 https://webhook.yeonsik.com/health 테스트

### 방법 2: 설정 파일 방식 (기술적 해결)

현재 시스템에 이미 준비된 설정:
- 설정 파일: `/home/y30n51k/github-ai-review-system/cloudflared-config.yml`
- DNS 라우팅: 이미 구성됨

**필요한 단계:**
1. sudo 권한으로 cloudflared 서비스 재시작
2. 설정 파일 기반 실행으로 변경

```bash
sudo systemctl stop cloudflared
sudo cloudflared --config /home/y30n51k/github-ai-review-system/cloudflared-config.yml tunnel run webhook
```

### 방법 3: 대체 터널 서비스 (임시 해결)

**ngrok 사용:**
```bash
# ngrok 설치 (필요시)
curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install ngrok

# 터널 시작
ngrok http 3000

# 제공된 URL (예: https://abc123.ngrok.io)을 GitHub 웹훅에 설정
```

**GitHub 웹훅 URL 업데이트:**
```bash
gh api orgs/team-off-the-record/hooks/562940845 \
  --method PATCH \
  --field config.url="https://새로운터널URL/webhook"
```

## 🧪 테스트 방법

### 1. 터널 수정 후 테스트
```bash
# 건강 상태 확인
curl https://webhook.yeonsik.com/health

# 웹훅 테스트
curl -X POST https://webhook.yeonsik.com/webhook \
  -H "Content-Type: application/json" \
  -H "X-GitHub-Event: ping" \
  -d '{"test": true}'
```

### 2. 전체 시스템 테스트
```bash
# 건강 상태 모니터링
./webhook-health-monitor.sh

# 수동 리뷰 트리거
./manual-trigger-review.sh team-off-the-record/off-the-record-server 1
```

## 📅 예상 해결 시간

- **방법 1 (Dashboard)**: 5-15분 (DNS 전파 포함)
- **방법 2 (Config파일)**: 2-5분 (sudo 권한 필요)
- **방법 3 (대체터널)**: 1-3분 (즉시 사용 가능)

## 🎯 추천 순서

1. **방법 1**: Cloudflare Dashboard에서 ingress 규칙 추가 (가장 안정적)
2. **방법 3**: ngrok으로 임시 해결하여 시스템 테스트 (즉시 확인)
3. **방법 2**: sudo 권한 확보 후 설정 파일 적용 (완전한 해결)

현재 AI 리뷰 시스템의 모든 다른 구성요소는 정상 작동 중이므로, 터널 문제만 해결되면 완전한 자동 리뷰 시스템이 작동합니다.