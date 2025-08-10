sh
export ANTHROPIC_API_KEY="your_anthropic_api_key"
export GITHUB_WEBHOOK_TOKEN="your_github_personal_access_token"  # repo, admin:org 권한 필요
export GITHUB_WEBHOOK_SECRET="your_webhook_secret_here"
export ORGANIZATION_NAME="your_github_organization"
```

환경변수 적용: `source ~/.bashrc`

## 🔧 1단계: GitHub CLI 인증 및 권한 확인

### GitHub CLI 설정
```bash
# GitHub CLI 설치 확인 및 인증
if ! command -v gh &> /dev/null; then
    echo "Installing GitHub CLI..."
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt update && sudo apt install gh
fi

# GitHub 인증 (필요시)
gh auth status || gh auth login

# Organization 권한 확인
gh api orgs/$ORGANIZATION_NAME || echo "⚠️ Organization access check failed"
```

## 🌐 2단계: Organization 웹훅 자동 설정

### 웹훅 설정 스크립트 생성 및 실행
다음 스크립트를 생성하고 실행하세요:

```bash
# setup-org-webhook.sh 파일 생성
cat > setup-org-webhook.sh << 'EOF'
#!/bin/bash
# Organization 레벨 웹훅 자동 설정

set -e

ORGANIZATION=$1
WEBHOOK_URL="https://webhook.yeonsik.kim/webhook"
WEBHOOK_SECRET=$2

# 사용법 체크
if [ -z "$ORGANIZATION" ] || [ -z "$WEBHOOK_SECRET" ]; then
    echo "Usage: $0 <organization-name> <webhook-secret>"
    echo "Example: $0 myorg mysecretkey123"
    exit 1
fi

echo "🚀 Setting up Organization webhook for: $ORGANIZATION"
echo "📡 Webhook URL: $WEBHOOK_URL"

# GitHub CLI 인증 상태 확인
if ! gh auth status > /dev/null 2>&1; then
    echo "❌ GitHub CLI not authenticated. Please run 'gh auth login' first."
    exit 1
fi

# Organization 존재 및 권한 확인
if ! gh api orgs/$ORGANIZATION > /dev/null 2>&1; then
    echo "❌ Cannot access organization '$ORGANIZATION'. Check organization name and permissions."
    exit 1
fi

echo "✅ Organization access confirmed"

# 기존 웹훅 확인 및 처리
echo "🔍 Checking for existing webhooks..."
EXISTING_WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks --jq '.[].config.url' 2>/dev/null || echo "")

if echo "$EXISTING_WEBHOOKS" | grep -q "$WEBHOOK_URL"; then
    echo "⚠️  Webhook already exists for this URL"
    HOOK_ID=$(gh api orgs/$ORGANIZATION/hooks --jq '.[] | select(.config.url == "'$WEBHOOK_URL'") | .id')
    gh api orgs/$ORGANIZATION/hooks/$HOOK_ID --method DELETE
    echo "🗑️  Existing webhook deleted"
fi

# 새 웹훅 생성
echo "📝 Creating organization webhook..."

WEBHOOK_RESPONSE=$(gh api orgs/$ORGANIZATION/hooks \
  --method POST \
  --field name=web \
  --field active=true \
  --raw-field config='{
    "url": "'$WEBHOOK_URL'",
    "content_type": "json",
    "secret": "'$WEBHOOK_SECRET'",
    "insecure_ssl": "0"
  }' \
  --raw-field events='[
    "pull_request",
    "issue_comment",
    "pull_request_review"
  ]' 2>/dev/null)

HOOK_ID=$(echo "$WEBHOOK_RESPONSE" | jq -r '.id')

if [ "$HOOK_ID" != "null" ] && [ -n "$HOOK_ID" ]; then
    echo "✅ Organization webhook created successfully!"
    echo "   Hook ID: $HOOK_ID"
    echo "   URL: $WEBHOOK_URL"
    echo "   Events: pull_request, issue_comment, pull_request_review"
    echo ""
    echo "🔧 This webhook will receive events from ALL repositories in the organization."
else
    echo "❌ Failed to create webhook."
    exit 1
fi

# 웹훅 연결 테스트
echo "🧪 Testing webhook connectivity..."
if curl -s --max-time 10 "$WEBHOOK_URL/health" > /dev/null 2>&1; then
    echo "✅ Webhook endpoint is reachable"
else
    echo "⚠️  Warning: Webhook endpoint test failed"
    echo "   Make sure Cloudflare Tunnel is running: systemctl status cloudflared-tunnel"
fi

echo "🎉 Organization webhook setup completed!"
EOF

chmod +x setup-org-webhook.sh

# 웹훅 설정 실행
./setup-org-webhook.sh $ORGANIZATION_NAME $GITHUB_WEBHOOK_SECRET
```

### 웹훅 상태 확인 스크립트 생성
```bash
# 웹훅 상태 확인 스크립트 생성
cat > check-org-webhook.sh << 'EOF'
#!/bin/bash
# Organization 웹훅 상태 확인

ORGANIZATION=$1

if [ -z "$ORGANIZATION" ]; then
    echo "Usage: $0 <organization-name>"
    exit 1
fi

echo "🔍 Checking webhooks for organization: $ORGANIZATION"

WEBHOOKS=$(gh api orgs/$ORGANIZATION/hooks 2>/dev/null)
if [ $? -ne 0 ]; then
    echo "❌ Failed to retrieve webhooks"
    exit 1
fi

WEBHOOK_COUNT=$(echo "$WEBHOOKS" | jq '. | length')
echo "📋 Found $WEBHOOK_COUNT webhook(s)"

if [ "$WEBHOOK_COUNT" -gt 0 ]; then
    echo "$WEBHOOKS" | jq -r '.[] | "ID: \(.id) | URL: \(.config.url) | Active: \(.active) | Events: \(.events | join(", "))"'
    
    # Claude Review 웹훅 확인
    WEBHOOK_URL="https://webhook.yeonsik.kim/webhook"
    CLAUDE_WEBHOOK=$(echo "$WEBHOOKS" | jq --arg url "$WEBHOOK_URL" '.[] | select(.config.url == $url)')
    
    if [ -n "$CLAUDE_WEBHOOK" ] && [ "$CLAUDE_WEBHOOK" != "null" ]; then
        echo "✅ Claude Review webhook is active"
    else
        echo "❌ Claude Review webhook not found"
    fi
fi
EOF

chmod +x check-org-webhook.sh

# 웹훅 상태 확인
./check-org-webhook.sh $ORGANIZATION_NAME
```

## 🤖 3단계: SubAgent 검토 및 생성/보완

**먼저 기존 SubAgent들을 확인하고 보완하세요:**

### 기존 에이전트 분석
Claude에서 `/agents` 실행 후 다음 패턴의 에이전트가 있는지 확인:
- architecture* 또는 architect* 관련
- security* 관련  
- performance* 관련
- ux* 또는 frontend* 관련

### 에이전트별 처리 방법

#### Architecture Reviewer 처리
**기존 에이전트가 있는 경우**:
```
기존 architecture 관련 에이전트의 시스템 프롬프트를 검토하고 다음 요소들이 포함되어 있는지 확인:

현재 시스템 프롬프트: [기존 내용 표시]

다음 요소들이 누락되었다면 보완:
- 시스템 설계 패턴 및 아키텍처 원칙 분석
- 코드 조직화 및 모듈성 평가
- 의존성 관리 및 결합도 분석  
- 확장성 및 유지보수성 우려사항
- 디자인 패턴 사용법 및 안티패턴 식별
- 장기적 기술부채 영향 평가
- Critical/High/Medium/Low 우선순위 지정

부족한 부분이 있으면 에이전트 업데이트 또는 새로 생성을 제안해주세요.
```

**새로 생성하는 경우**:
```
이름: architecture-reviewer
설명: Senior software architect for comprehensive code reviews
시스템 프롬프트: You are a senior software architect with 15+ years of experience. When reviewing code changes, focus on:

CORE RESPONSIBILITIES:
- System design patterns and architectural principles
- Code organization, modularity, and separation of concerns
- Dependency management and coupling analysis
- Scalability and maintainability implications
- Design pattern usage and anti-pattern identification
- Long-term technical debt assessment
- API design and interface contracts

ANALYSIS APPROACH:
1. Evaluate overall architectural impact of changes
2. Identify potential scalability bottlenecks
3. Assess code organization and structure
4. Review dependency management practices
5. Check for proper separation of concerns

OUTPUT FORMAT:
- Rate each issue: Critical/High/Medium/Low
- Provide specific, actionable recommendations
- Include code examples when beneficial
- Consider both immediate and long-term implications

Focus on architectural excellence while being practical about implementation constraints.
```

#### Security Reviewer 처리
**기존 에이전트 확인 후 보완/생성**:
```
이름: security-reviewer  
설명: Cybersecurity expert specializing in secure code practices
시스템 프롬프트: You are a cybersecurity expert with deep expertise in application security. When reviewing code changes, focus on:

SECURITY PRIORITIES:
- OWASP Top 10 vulnerabilities (2023)
- Authentication and authorization mechanisms
- Input validation and data sanitization
- Injection attacks (SQL, NoSQL, LDAP, OS command)
- Cross-Site Scripting (XSS) and CSRF protection
- Secrets management and sensitive data handling
- Cryptography implementation and key management
- API security and data exposure risks

ANALYSIS METHODOLOGY:
1. Scan for common vulnerability patterns
2. Evaluate access control implementations
3. Review data flow and trust boundaries
4. Assess error handling and information disclosure
5. Check for hardcoded credentials or secrets

OUTPUT REQUIREMENTS:
- Severity: Critical/High/Medium/Low
- CVE references when applicable
- Specific remediation steps with code examples
- Security best practices recommendations
- Compliance considerations (GDPR, PCI-DSS, etc.)

Prioritize practical security improvements that developers can implement immediately.
```

#### Performance Reviewer 처리
**기존 에이전트 확인 후 보완/생성**:
```
이름: performance-reviewer
설명: Performance engineering expert for optimization analysis  
시스템 프롬프트: You are a performance engineering expert with extensive experience optimizing applications at scale. When reviewing code changes, focus on:

PERFORMANCE DOMAINS:
- Algorithm complexity analysis (Big O notation)
- Memory usage patterns and garbage collection impact
- Database query optimization and N+1 problem detection
- Caching strategies and cache invalidation
- Resource utilization and bottleneck identification
- Concurrency and parallel processing opportunities
- Network I/O optimization and data transfer efficiency
- Frontend performance (if applicable)

ANALYSIS FRAMEWORK:
1. Identify computational complexity issues
2. Evaluate memory allocation patterns
3. Review database interaction efficiency
4. Assess caching implementation
5. Consider scalability under load
6. Analyze resource consumption patterns

OUTPUT SPECIFICATIONS:
- Performance impact rating: Critical/High/Medium/Low
- Quantitative improvement estimates when possible
- Specific optimization recommendations
- Benchmarking suggestions
- Load testing considerations
- Monitoring and observability recommendations

Focus on measurable performance improvements with clear ROI justification.
```

#### UX Reviewer 처리  
**기존 에이전트 확인 후 보완/생성**:
```
이름: ux-reviewer
설명: User experience and accessibility specialist
시스템 프롬프트: You are a UX specialist and accessibility expert focused on creating excellent user experiences. When reviewing code changes, focus on:

UX EVALUATION AREAS:
- User interface usability and intuitive design
- Accessibility compliance (WCAG 2.1 AA+ standards)
- Responsive design and cross-device compatibility  
- Performance impact on user experience
- Error handling and user feedback mechanisms
- Form design and input validation UX
- Loading states and progressive enhancement
- Micro-interactions and user flow optimization

ACCESSIBILITY REQUIREMENTS:
- Screen reader compatibility
- Keyboard navigation support
- Color contrast and visual accessibility
- Focus management and tab order
- ARIA labels and semantic markup
- Touch target sizing and mobile usability

ANALYSIS PROCESS:
1. Evaluate user interaction patterns
2. Check accessibility compliance
3. Assess responsive design implementation
4. Review error handling from user perspective
5. Consider performance impact on UX
6. Validate form and input experiences

OUTPUT FORMAT:
- UX impact rating: Critical/High/Medium/Low
- Accessibility compliance score
- Specific user experience improvements
- Cross-browser/device testing recommendations
- User testing suggestions
- Progressive enhancement opportunities

Balance ideal user experience with practical implementation constraints.
```

## 🔧 4단계: MCP 서버 확인 및 설정

**기존 MCP 서버를 먼저 확인하고 활용하세요:**

### MCP 서버 현황 점검
```bash
# 기존 MCP 서버 확인
claude mcp list

# 또는 Claude 내에서
/mcp
```

### GitHub MCP 서버 처리 로직
**다음 순서로 확인하고 설정:**

1. **기존 GitHub MCP 확인**:
   - `github` 또는 유사한 이름의 MCP 서버가 있는지 확인
   - 있다면 기능 테스트: "List my GitHub repositories"

2. **기존 서버 활용 가능시**:
   ```
   기존 GitHub MCP 서버를 발견했습니다. 다음 기능들이 작동하는지 테스트:
   - Repository 목록 조회
   - Issue/PR 생성 및 댓글
   - 파일 내용 읽기
   - Commit 및 Push 작업
   
   모든 기능이 정상이면 기존 서버 사용, 문제가 있으면 재설정 또는 새로 추가
   ```

3. **새로 설정 필요시**:
   ```bash
   # 대화형 설정
   claude mcp add
   
   # 또는 직접 JSON 설정
   claude mcp add-json github '{
     "command": "npx",
     "args": ["-y", "@modelcontextprotocol/server-github"],
     "env": {
       "GITHUB_PERSONAL_ACCESS_TOKEN": "'$GITHUB_WEBHOOK_TOKEN'"
     }
   }'
   ```

## 🚫 5단계: 리뷰 스킵 기능 구현

**PR 제목이나 본문에 특정 키워드가 있으면 리뷰를 건너뛰는 기능을 추가하세요:**

### 스킵 키워드 정의
웹훅 서버에서 다음 키워드들을 감지하면 리뷰 스킵:
- `[skip-review]` 또는 `[skip review]`
- `[no-review]` 또는 `[no review]`  
- `[manual-review]` 또는 `[manual review]`
- `[urgent]` (긴급 배포용)
- `[hotfix]` (핫픽스용)
- `[wip]` 또는 `[work in progress]` (작업 중)

### 스킵 로직 구현
```javascript
// 웹훅 서버에 추가할 함수
function shouldSkipReview(prData) {
  const skipKeywords = [
    /\[skip[-\s]?review\]/i,
    /\[no[-\s]?review\]/i,
    /\[manual[-\s]?review\]/i,
    /\[urgent\]/i,
    /\[hotfix\]/i,
    /\[wip\]/i,
    /\[work\s+in\s+progress\]/i
  ];
  
  const title = prData.pull_request.title || '';
  const body = prData.pull_request.body || '';
  const combinedText = title + ' ' + body;
  
  const shouldSkip = skipKeywords.some(keyword => keyword.test(combinedText));
  
  if (shouldSkip) {
    console.log(`Skipping review for PR #${prData.pull_request.number}: Skip keyword detected`);
    // GitHub에 스킵 사유 댓글 등록
    postSkipComment(prData, combinedText);
    return true;
  }
  
  return false;
}

// 스킵 사유 댓글 등록
async function postSkipComment(prData, text) {
  const skipReason = detectSkipReason(text);
  const comment = `
## 🤖 AI Review Skipped

**Reason**: ${skipReason}

This PR was marked to skip automated review. If you want to enable review, please:
1. Remove the skip keyword from title/description
2. Add a new comment with: \`@claude-bot review\`

---
*Available skip keywords: [skip-review], [no-review], [manual-review], [urgent], [hotfix], [wip]*
  `;
  
  // GitHub MCP를 통해 댓글 등록
  await postGitHubComment(prData.repo, prData.pr_number, comment);
}
```

### 수동 리뷰 트리거 기능
**PR 댓글로 리뷰 강제 실행:**
```javascript
// PR 댓글 이벤트 처리
app.post('/webhook', (req, res) => {
  if (req.body.action === 'comment_created') {
    const comment = req.body.comment.body.toLowerCase();
    
    // 리뷰 트리거 키워드 감지
    if (comment.includes('@claude-bot review') || 
        comment.includes('claude review') ||
        comment.includes('/review')) {
      
      console.log('Manual review triggered by comment');
      triggerManualReview(req.body);
    }
  }
  
  // 기존 PR 이벤트 처리...
});
```

## 🌐 6단계: 웹훅 서버 구현 및 서비스 설정

### 웹훅 서버 디렉토리 구조 생성
```bash
# 웹훅 서버 프로젝트 디렉토리 생성
sudo mkdir -p /opt/claude-webhook-server
sudo chown $USER:$USER /opt/claude-webhook-server
cd /opt/claude-webhook-server

# 프로젝트 초기화
npm init -y
npm install express crypto child_process fs path dotenv winston
```

### 완전한 웹훅 서버 구현
```javascript
# webhook-server.js 파일 생성
cat > webhook-server.js << 'EOF'
const express = require('express');
const crypto = require('crypto');
const { spawn, exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 3000;
const TEMP_DIR = '/tmp/claude-reviews';

// 로깅 설정
const winston = require('winston');
const logger = winston.createLogger({
    level: 'info',
    format: winston.format.combine(
        winston.format.timestamp(),
        winston.format.json()
    ),
    transports: [
        new winston.transports.File({ filename: '/var/log/claude-webhook-error.log', level: 'error' }),
        new winston.transports.File({ filename: '/var/log/claude-webhook.log' }),
        new winston.transports.Console({
            format: winston.format.simple()
        })
    ]
});

app.use(express.json({ limit: '10mb' }));

// Health check endpoint
app.get('/health', (req, res) => {
    res.json({
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'claude-webhook-server',
        version: '1.0.0'
    });
});

// GitHub 시크릿 검증
function verifyGitHubSignature(payload, signature, secret) {
    const hmac = crypto.createHmac('sha256', secret);
    const digest = 'sha256=' + hmac.update(payload, 'utf8').digest('hex');
    
    return crypto.timingSafeEqual(
        Buffer.from(signature), 
        Buffer.from(digest)
    );
}

// 리뷰 스킵 검사
function shouldSkipReview(prData) {
    const skipKeywords = [
        /\[skip[-\s]?review\]/i,
        /\[no[-\s]?review\]/i,
        /\[manual[-\s]?review\]/i,
        /\[urgent\]/i,
        /\[hotfix\]/i,
        /\[wip\]/i,
        /\[work\s+in\s+progress\]/i
    ];
    
    const title = prData.pull_request.title || '';
    const body = prData.pull_request.body || '';
    const combinedText = title + ' ' + body;
    
    return skipKeywords.some(keyword => keyword.test(combinedText));
}

// Organization 정보를 포함한 PR 데이터 추출
function extractPRData(eventData) {
    return {
        organization: eventData.organization?.login,
        repo: eventData.repository.full_name,
        pr_number: eventData.pull_request.number,
        title: eventData.pull_request.title,
        body: eventData.pull_request.body,
        head_sha: eventData.pull_request.head.sha,
        base_branch: eventData.pull_request.base.ref,
        head_branch: eventData.pull_request.head.ref,
        author: eventData.pull_request.user.login
    };
}

// PR 이벤트 처리
async function handlePullRequestEvent(eventData) {
    const prData = extractPRData(eventData);
    logger.info(`Processing PR #${prData.pr_number} from ${prData.repo}`);
    
    // 스킵 검사
    if (shouldSkipReview(prData)) {
        logger.info(`Skipping review for PR #${prData.pr_number}: Skip keyword detected`);
        await postSkipComment(prData);
        return;
    }
    
    // AI 리뷰 실행
    await executeAIReview(prData);
}

// 댓글 이벤트 처리 (수동 트리거)
async function handleCommentEvent(eventData) {
    const comment = eventData.comment.body.toLowerCase();
    
    if (comment.includes('@claude-bot review') || 
        comment.includes('claude review') ||
        comment.includes('/review')) {
        
        logger.info('Manual review triggered by comment');
        const prData = extractPRData(eventData);
        await executeAIReview(prData);
    }
}

// AI 리뷰 실행
async function executeAIReview(prData) {
    const reviewId = `${prData.repo.replace('/', '-')}-${prData.pr_number}`;
    const workDir = path.join(TEMP_DIR, reviewId);
    
    try {
        // 작업 디렉토리 생성
        await fs.mkdir(workDir, { recursive: true });
        
        // 저장소 클론
        await cloneRepository(prData, workDir);
        
        // 4개 SubAgent 병렬 실행
        const reviews = await runSubAgentReviews(workDir, prData);
        
        // Main Agent로 통합 및 코드 수정
        await integrateAndApplyReviews(workDir, prData, reviews);
        
        // 정리
        await fs.rm(workDir, { recursive: true, force: true });
        
    } catch (error) {
        logger.error(`Review failed for PR #${prData.pr_number}:`, error);
        await postErrorComment(prData, error);
    }
}

// 저장소 클론
async function cloneRepository(prData, workDir) {
    return new Promise((resolve, reject) => {
        const cloneCmd = `git clone https://github.com/${prData.repo}.git ${workDir}/repo && cd ${workDir}/repo && git checkout ${prData.head_sha}`;
        exec(cloneCmd, (error, stdout, stderr) => {
            if (error) {
                logger.error(`Clone failed: ${error}`);
                reject(error);
            } else {
                logger.info(`Repository cloned successfully: ${prData.repo}`);
                resolve();
            }
        });
    });
}

// SubAgent 리뷰 실행
async function runSubAgentReviews(workDir, prData) {
    const repoPath = path.join(workDir, 'repo');
    const agents = [
        'architecture-reviewer',
        'security-reviewer', 
        'performance-reviewer',
        'ux-reviewer'
    ];

    const reviewPromises = agents.map(agentName => 
        runSpecificAgent(agentName, repoPath, prData)
    );
    
    const results = await Promise.all(reviewPromises);
    
    const reviews = {};
    agents.forEach((agentName, index) => {
        reviews[agentName] = results[index];
    });
    
    return reviews;
}

// 특정 SubAgent 실행
function runSpecificAgent(agentName, repoPath, prData) {
    return new Promise((resolve, reject) => {
        const prompt = `Review this PR for ${agentName.replace('-reviewer', '')} concerns:
        
Repository: ${prData.repo}
PR #${prData.pr_number}: ${prData.title}

Please analyze the code changes and provide specific recommendations.`;
        
        const claudeCmd = `cd ${repoPath} && echo "${prompt}" | claude --agent ${agentName} --print`;
        
        exec(claudeCmd, { maxBuffer: 1024 * 1024 * 10, timeout: 300000 }, (error, stdout, stderr) => {
            if (error) {
                logger.error(`${agentName} failed:`, error);
                resolve({ error: error.message, agent: agentName });
            } else {
                logger.info(`${agentName} completed successfully`);
                resolve({ 
                    output: stdout, 
                    agent: agentName,
                    timestamp: new Date().toISOString()
                });
            }
        });
    });
}

// 통합 분석 및 코드 수정
async function integrateAndApplyReviews(workDir, prData, reviews) {
    const repoPath = path.join(workDir, 'repo');
    
    const integrationPrompt = `Based on these specialist reviews, analyze and apply safe code modifications:

${Object.entries(reviews).map(([agent, review]) => 
    `## ${agent.toUpperCase()}\n${review.output || review.error}`
).join('\n\n')}

Instructions:
1. Only make changes that are clearly beneficial and low-risk
2. Create appropriate commit messages
3. If uncertain, document as comment instead`;

    return new Promise((resolve, reject) => {
        const claudeCmd = `cd ${repoPath} && echo "${integrationPrompt}" | claude --print`;
        
        exec(claudeCmd, { maxBuffer: 1024 * 1024 * 20, timeout: 600000 }, async (error, stdout, stderr) => {
            if (error) {
                logger.error('Integration failed:', error);
                reject(error);
            } else {
                logger.info('Integration completed');
                
                // 변경사항 푸시 시도
                await pushChanges(repoPath, prData);
                
                // GitHub 댓글 등록
                await postReviewComments(prData, reviews, stdout);
                resolve();
            }
        });
    });
}

// 변경사항 푸시
async function pushChanges(repoPath, prData) {
    return new Promise((resolve) => {
        const pushCmd = `cd ${repoPath} && git push origin ${prData.head_branch} 2>/dev/null || echo "No changes to push"`;
        
        exec(pushCmd, (error, stdout, stderr) => {
            if (error) {
                logger.warn('Push failed or no changes:', error.message);
            } else {
                logger.info('Changes pushed successfully');
            }
            resolve();
        });
    });
}

// GitHub 댓글 등록
async function postReviewComments(prData, reviews, integrationResult) {
    const [owner, repo] = prData.repo.split('/');
    
    const reviewSummary = `## 🤖 AI Code Review Summary

### 📊 Review Results:
${Object.entries(reviews).map(([agent, review]) => {
    const icon = {
        'architecture-reviewer': '🏗️',
        'security-reviewer': '🛡️', 
        'performance-reviewer': '⚡',
        'ux-reviewer': '🎨'
    }[agent] || '🤖';
    
    return `#### ${icon} ${agent.replace('-reviewer', '').toUpperCase()}
${review.error ? '❌ Review failed: ' + review.error : '✅ Review completed'}`;
}).join('\n\n')}

### 🔧 Integration Results:
${integrationResult.substring(0, 1000)}...

---
*This review was automatically generated by AI SubAgents.*`;

    // Claude CLI를 통해 GitHub MCP 사용하여 댓글 등록
    const commentCmd = `claude "Post this review summary as a comment on PR ${prData.pr_number} in ${prData.repo}: ${reviewSummary.replace(/"/g, '\\"')}"`;
    
    exec(commentCmd, { timeout: 30000 }, (error, stdout, stderr) => {
        if (error) {
            logger.error('Failed to post comment:', error);
        } else {
            logger.info('Review comment posted successfully');
        }
    });
}

// 스킵 댓글 등록
async function postSkipComment(prData) {
    const comment = `## 🤖 AI Review Skipped

This PR was marked to skip automated review. 

To enable review:
1. Remove skip keywords from title/description
2. Comment: \`@claude-bot review\`

*Skip keywords: [skip-review], [no-review], [manual-review], [urgent], [hotfix], [wip]*`;
    
    const commentCmd = `claude "Post this comment on PR ${prData.pr_number} in ${prData.repo}: ${comment.replace(/"/g, '\\"')}"`;
    
    exec(commentCmd, (error) => {
        if (error) {
            logger.error('Failed to post skip comment:', error);
        } else {
            logger.info('Skip comment posted successfully');
        }
    });
}

// 에러 댓글 등록
async function postErrorComment(prData, error) {
    const errorComment = `## ❌ AI Review Failed

An error occurred during the automated review process:

\`\`\`
${error.message}
\`\`\`

Please check the webhook server logs for more details.`;

    const commentCmd = `claude "Post this error comment on PR ${prData.pr_number} in ${prData.repo}: ${errorComment.replace(/"/g, '\\"')}"`;
    
    exec(commentCmd, (error) => {
        if (error) {
            logger.error('Failed to post error comment:', error);
        }
    });
}

// 메인 웹훅 핸들러
app.post('/webhook', async (req, res) => {
    const signature = req.headers['x-hub-signature-256'];
    const payload = JSON.stringify(req.body);
    
    // GitHub 시크릿 검증
    if (!verifyGitHubSignature(payload, signature, process.env.GITHUB_WEBHOOK_SECRET)) {
        logger.warn('Unauthorized webhook request');
        return res.status(401).send('Unauthorized');
    }

    const eventType = req.headers['x-github-event'];
    const eventData = req.body;

    logger.info(`Received ${eventType} event from ${eventData.organization?.login || eventData.repository?.full_name || 'unknown'}`);

    // 비동기 처리로 빠른 응답
    res.status(200).send('OK');

    try {
        switch (eventType) {
            case 'pull_request':
                if (['opened', 'synchronize'].includes(eventData.action)) {
                    await handlePullRequestEvent(eventData);
                }
                break;
                
            case 'issue_comment':
                if (eventData.action === 'created' && eventData.issue.pull_request) {
                    await handleCommentEvent(eventData);
                }
                break;
                
            default:
                logger.info(`Ignoring ${eventType} event`);
        }
    } catch (error) {
        logger.error('Webhook processing error:', error);
    }
});

// 서버 시작
app.listen(PORT, '127.0.0.1', () => {
    logger.info(`Claude Webhook Server running on localhost:${PORT}`);
    logger.info('Environment variables loaded:', {
        ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY ? 'Set' : 'Missing',
        GITHUB_WEBHOOK_TOKEN: process.env.GITHUB_WEBHOOK_TOKEN ? 'Set' : 'Missing',
        GITHUB_WEBHOOK_SECRET: process.env.GITHUB_WEBHOOK_SECRET ? 'Set' : 'Missing',
        ORGANIZATION_NAME: process.env.ORGANIZATION_NAME || 'Not set'
    });
});

// 우아한 종료 처리
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    process.exit(0);
});
EOF
```

### 환경 설정 파일 생성
```bash
# .env 파일 생성
cat > .env << EOF
PORT=3000
ANTHROPIC_API_KEY=${ANTHROPIC_API_KEY}
GITHUB_WEBHOOK_TOKEN=${GITHUB_WEBHOOK_TOKEN}
GITHUB_WEBHOOK_SECRET=${GITHUB_WEBHOOK_SECRET}
ORGANIZATION_NAME=${ORGANIZATION_NAME}
NODE_ENV=production
EOF

# 권한 설정
chmod 600 .env
```

### Systemd 서비스 파일 생성
```bash
# 서비스 파일 생성
sudo tee /etc/systemd/system/claude-webhook.service > /dev/null <<EOF
[Unit]
Description=Claude AI Review Webhook Server
Documentation=https://github.com/your-org/claude-webhook-server
After=network.target

[Service]
Type=simple
User=$USER
Group=$USER
WorkingDirectory=/opt/claude-webhook-server
Environment=NODE_ENV=production
ExecStart=/usr/bin/node webhook-server.js
ExecReload=/bin/kill -HUP \$MAINPID
Restart=always
RestartSec=5
StartLimitInterval=60s
StartLimitBurst=3

# 로그 설정
StandardOutput=journal
StandardError=journal
SyslogIdentifier=claude-webhook

# 보안 설정
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ProtectHome=yes
ReadWritePaths=/opt/claude-webhook-server /tmp /var/log

# 리소스 제한
LimitNOFILE=65536
LimitNPROC=4096

[Install]
WantedBy=multi-user.target
EOF

# 서비스 권한 설정
sudo chmod 644 /etc/systemd/system/claude-webhook.service
```

### 로그 디렉토리 및 로테이션 설정
```bash
# 로그 파일 생성
sudo touch /var/log/claude-webhook.log /var/log/claude-webhook-error.log
sudo chown $USER:$USER /var/log/claude-webhook.log /var/log/claude-webhook-error.log

# 로그 로테이션 설정
sudo tee /etc/logrotate.d/claude-webhook > /dev/null <<EOF
/var/log/claude-webhook*.log {
    daily
    missingok
    rotate 30
    compress
    delaycompress
    notifempty
    create 644 $USER $USER
    postrotate
        systemctl reload claude-webhook > /dev/null 2>&1 || true
    endscript
}
EOF
```

### 서비스 등록 및 시작
```bash
# systemd 데몬 리로드
sudo systemctl daemon-reload

# 서비스 활성화 (부팅 시 자동 시작)
sudo systemctl enable claude-webhook

# 서비스 시작
sudo systemctl start claude-webhook

# 서비스 상태 확인
sudo systemctl status claude-webhook

# 서비스 로그 확인
journalctl -u claude-webhook -f
```

### 서비스 관리 스크립트 생성
```bash
# 서비스 관리 스크립트 생성
cat > manage-webhook-service.sh << 'EOF'
#!/bin/bash
# Claude Webhook Service 관리 스크립트

SERVICE_NAME="claude-webhook"

case "$1" in
    start)
        echo "Starting $SERVICE_NAME service..."
        sudo systemctl start $SERVICE_NAME
        ;;
    stop)
        echo "Stopping $SERVICE_NAME service..."
        sudo systemctl stop $SERVICE_NAME
        ;;
    restart)
        echo "Restarting $SERVICE_NAME service..."
        sudo systemctl restart $SERVICE_NAME
        ;;
    status)
        sudo systemctl status $SERVICE_NAME
        ;;
    logs)
        echo "Showing logs for $SERVICE_NAME service..."
        journalctl -u $SERVICE_NAME -f
        ;;
    enable)
        echo "Enabling $SERVICE_NAME service for auto-start..."
        sudo systemctl enable $SERVICE_NAME
        ;;
    disable)
        echo "Disabling $SERVICE_NAME service auto-start..."
        sudo systemctl disable $SERVICE_NAME
        ;;
    health)
        echo "Checking service health..."
        curl -f http://localhost:3000/health || echo "Service is not responding"
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|logs|enable|disable|health}"
        exit 1
        ;;
esac
EOF

chmod +x manage-webhook-service.sh

# 사용 예시 출력
echo "✅ Webhook service setup completed!"
echo ""
echo "Service management commands:"
echo "  ./manage-webhook-service.sh start    - Start service"
echo "  ./manage-webhook-service.sh stop     - Stop service" 
echo "  ./manage-webhook-service.sh restart  - Restart service"
echo "  ./manage-webhook-service.sh status   - Check status"
echo "  ./manage-webhook-service.sh logs     - View logs"
echo "  ./manage-webhook-service.sh health   - Health check"
echo ""
echo "Service will automatically start on boot."
echo "Check service status: sudo systemctl status claude-webhook"
```

## ⚠️ 7단계: 종합 테스트

### Organization 웹훅 테스트
```bash
# 1. 웹훅 상태 최종 확인
./check-org-webhook.sh $ORGANIZATION_NAME

# 2. Organization 내 아무 저장소에 테스트 PR 생성
cd /tmp
git clone https://github.com/$ORGANIZATION_NAME/[any-repo]
cd [any-repo]
git checkout -b test-webhook-$(date +%s)
echo "# Test PR for webhook" > test-webhook.md
git add test-webhook.md
git commit -m "Test: webhook functionality"
git push origin HEAD
gh pr create --title "[TEST] Webhook functionality test" --body "Testing organization-level webhook for AI review system"

# 3. 웹훅 서버 로그 확인
tail -f /var/log/webhook-server.log

# 4. GitHub Organization 웹훅 전송 로그 확인
# https://github.com/orgs/$ORGANIZATION_NAME/settings/hooks
```

## 📊 8단계: 모니터링 및 운영

### Organization 레벨 모니터링 대시보드
```bash
# 조직 전체 리뷰 통계 조회 스크립트
cat > org-review-stats.sh << 'EOF'
#!/bin/bash
ORGANIZATION=$1
DAYS=${2:-7}

echo "📊 AI Review Statistics for $ORGANIZATION (Last $DAYS days)"
echo "================================================"

# Organization 저장소 목록
REPOS=$(gh api orgs/$ORGANIZATION/repos --paginate --jq '.[].full_name')

for repo in $REPOS; do
    echo "📁 $repo:"
    
    # 최근 PR 중 AI 리뷰가 있는 것들 확인
    RECENT_PRS=$(gh api repos/$repo/pulls --jq '.[] | select(.created_at > "'$(date -d "$DAYS days ago" -I)'") | .number')
    
    for pr_num in $RECENT_PRS; do
        AI_COMMENTS=$(gh api repos/$repo/issues/$pr_num/comments --jq '.[] | select(.user.login == "claude-bot" or (.body | contains("🤖 AI Review"))) | .created_at' 2>/dev/null | wc -l)
        if [ $AI_COMMENTS -gt 0 ]; then
            echo "  ✅ PR #$pr_num: $AI_COMMENTS AI review comments"
        fi
    done
done
EOF

chmod +x org-review-stats.sh
```

## 🎯 완료 기준

다음이 모두 동작해야 완료:
1. ✅ Organization 웹훅이 GitHub에 정상 등록됨
2. ✅ 4개 SubAgent가 생성되고 개별 테스트 통과
3. ✅ 웹훅 서버가 Organization 이벤트 수신 및 처리
4. ✅ Organization 내 아무 저장소의 PR 생성시 자동 리뷰 실행
5. ✅ 안전한 수정사항 자동 커밋 및 GitHub 댓글 등록
6. ✅ 리뷰 스킵 기능 정상 동작
7. ✅ 수동 트리거 기능 정상 동작

각 단계를 순차적으로 진행하고, 특히 Organization 웹훅 설정이 완료된 후 테스트를 충분히 수행해주세요. 문제 발생시 GitHub Organization settings에서 webhook delivery 로그를 확인할 수 있습니다.
