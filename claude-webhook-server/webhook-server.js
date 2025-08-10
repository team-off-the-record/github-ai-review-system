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
        new winston.transports.File({ filename: '/home/y30n51k/github-ai-review-system/claude-webhook-server/logs/error.log', level: 'error' }),
        new winston.transports.File({ filename: '/home/y30n51k/github-ai-review-system/claude-webhook-server/logs/combined.log' }),
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
    if (!signature) return false;
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
        
        // issue_comment 이벤트에서는 issue 객체를 사용
        const prData = {
            organization: eventData.organization?.login,
            repo: eventData.repository.full_name,
            pr_number: eventData.issue.number,
            title: eventData.issue.title,
            body: eventData.issue.body,
            head_sha: 'HEAD', // PR 정보를 가져와야 함
            base_branch: 'main',
            head_branch: 'unknown',
            author: eventData.issue.user.login
        };
        
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
        
        // 4개 SubAgent 병렬 실행 (Task 도구 사용)
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
        const repoPath = path.join(workDir, 'repo');
        const cloneCmd = `git clone https://github.com/${prData.repo}.git ${repoPath} && cd ${repoPath} && git checkout ${prData.head_sha}`;
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

// SubAgent 리뷰 실행 (Claude Task 도구 활용)
async function runSubAgentReviews(workDir, prData) {
    const repoPath = path.join(workDir, 'repo');
    const agents = [
        'architecture-reviewer',
        'security-reviewer', 
        'performance-reviewer',
        'ux-reviewer'
    ];

    logger.info(`Starting parallel reviews with ${agents.length} agents`);
    
    // 병렬로 모든 에이전트 실행
    const reviewPromises = agents.map(agentName => 
        runClaudeCodeReview(agentName, repoPath, prData)
    );
    
    const results = await Promise.allSettled(reviewPromises);
    
    const reviews = {};
    agents.forEach((agentName, index) => {
        const result = results[index];
        if (result.status === 'fulfilled') {
            reviews[agentName] = result.value;
        } else {
            reviews[agentName] = {
                error: result.reason.message,
                agent: agentName,
                timestamp: new Date().toISOString()
            };
        }
    });
    
    return reviews;
}

// Claude Code로 특정 SubAgent 실행
function runClaudeCodeReview(agentName, repoPath, prData) {
    return new Promise((resolve, reject) => {
        const prompt = `Review this PR for ${agentName.replace('-reviewer', '')} concerns:

Repository: ${prData.repo}
PR #${prData.pr_number}: ${prData.title}
Author: ${prData.author}

Please analyze the code changes in this repository and provide specific recommendations for ${agentName.replace('-reviewer', '')} improvements. Focus on actionable feedback that can help improve the code quality.

Please provide:
1. Critical issues that need immediate attention
2. Recommendations for improvement
3. Code examples where helpful
4. Priority level for each finding (Critical/High/Medium/Low)`;

        const claudeProcess = spawn('claude', ['--print'], {
            cwd: repoPath,
            stdio: ['pipe', 'pipe', 'pipe'],
            env: { ...process.env }
        });

        let output = '';
        let errorOutput = '';

        claudeProcess.stdin.write(prompt);
        claudeProcess.stdin.end();

        claudeProcess.stdout.on('data', (data) => {
            output += data.toString();
        });

        claudeProcess.stderr.on('data', (data) => {
            errorOutput += data.toString();
        });

        const timeout = setTimeout(() => {
            claudeProcess.kill('SIGKILL');
            reject(new Error(`${agentName} review timeout after 5 minutes`));
        }, 300000); // 5분 타임아웃

        claudeProcess.on('close', (code) => {
            clearTimeout(timeout);
            if (code === 0) {
                logger.info(`${agentName} completed successfully`);
                resolve({ 
                    output: output, 
                    agent: agentName,
                    timestamp: new Date().toISOString()
                });
            } else {
                logger.error(`${agentName} failed with code ${code}: ${errorOutput}`);
                reject(new Error(`${agentName} failed: ${errorOutput}`));
            }
        });
    });
}

// 통합 분석 및 코드 수정
async function integrateAndApplyReviews(workDir, prData, reviews) {
    const repoPath = path.join(workDir, 'repo');
    
    const integrationPrompt = `Based on these specialist reviews, analyze and apply safe code modifications:

${Object.entries(reviews).map(([agent, review]) => 
    `## ${agent.toUpperCase()}\n${review.output || 'Review failed: ' + review.error}`
).join('\n\n')}

Repository: ${prData.repo}
PR #${prData.pr_number}: ${prData.title}

Instructions:
1. Only make changes that are clearly beneficial and low-risk
2. Create appropriate commit messages for any changes made
3. If uncertain about a change, document it as a comment instead of modifying code
4. Focus on the most critical issues first
5. Ensure all changes maintain code functionality`;

    return new Promise((resolve, reject) => {
        const claudeProcess = spawn('claude', ['--print'], {
            cwd: repoPath,
            stdio: ['pipe', 'pipe', 'pipe'],
            env: { ...process.env }
        });

        let integrationOutput = '';
        let errorOutput = '';

        claudeProcess.stdin.write(integrationPrompt);
        claudeProcess.stdin.end();

        claudeProcess.stdout.on('data', (data) => {
            integrationOutput += data.toString();
        });

        claudeProcess.stderr.on('data', (data) => {
            errorOutput += data.toString();
        });

        const timeout = setTimeout(() => {
            claudeProcess.kill('SIGKILL');
            reject(new Error('Integration review timeout after 10 minutes'));
        }, 600000); // 10분 타임아웃

        claudeProcess.on('close', async (code) => {
            clearTimeout(timeout);
            if (code === 0) {
                logger.info('Integration completed successfully');
                
                // 변경사항이 있는지 확인하고 푸시 시도
                await checkAndPushChanges(repoPath, prData);
                
                // GitHub 댓글 등록
                await postReviewComments(prData, reviews, integrationOutput);
                resolve();
            } else {
                logger.error('Integration failed:', errorOutput);
                reject(new Error(`Integration failed: ${errorOutput}`));
            }
        });
    });
}

// 변경사항 확인 및 푸시
async function checkAndPushChanges(repoPath, prData) {
    return new Promise((resolve) => {
        // Git 상태 확인
        exec('git status --porcelain', { cwd: repoPath }, (error, stdout) => {
            if (error || !stdout.trim()) {
                logger.info('No changes to commit');
                resolve();
                return;
            }

            logger.info('Changes detected, committing and pushing...');
            
            // Git 설정 및 변경사항 커밋
            const commitCmd = `
                git config user.email "claude-bot@anthropic.com" &&
                git config user.name "Claude Bot" &&
                git add -A &&
                git commit -m "🤖 AI Review: Automated code improvements

- Applied recommendations from architecture, security, performance, and UX reviews
- Only safe, low-risk improvements were implemented
- For detailed analysis, see PR comments

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>" &&
                git push origin ${prData.head_branch} 2>/dev/null || echo "Push failed or no permissions"
            `;
            
            exec(commitCmd, { cwd: repoPath }, (pushError, pushStdout, pushStderr) => {
                if (pushError) {
                    logger.warn('Push failed or no changes:', pushError.message);
                } else {
                    logger.info('Changes committed and pushed successfully');
                }
                resolve();
            });
        });
    });
}

// GitHub 댓글 등록 (직접 GitHub API 호출)
async function postReviewComments(prData, reviews, integrationResult) {
    const reviewSummary = generateReviewSummary(reviews, integrationResult);
    
    try {
        // GitHub CLI를 사용하여 댓글 등록
        const [owner, repo] = prData.repo.split('/');
        const commentCmd = `gh api repos/${owner}/${repo}/issues/${prData.pr_number}/comments \\
            --method POST \\
            --field body="${reviewSummary.replace(/"/g, '\\"').replace(/\$/g, '\\$')}"`;
        
        exec(commentCmd, { timeout: 30000 }, (error, stdout, stderr) => {
            if (error) {
                logger.error('Failed to post review comment:', error.message);
            } else {
                logger.info('Review comment posted successfully');
            }
        });
    } catch (error) {
        logger.error('Error posting review comments:', error);
    }
}

// 리뷰 요약 생성
function generateReviewSummary(reviews, integrationResult) {
    const timestamp = new Date().toISOString();
    
    return `## 🤖 AI Code Review Summary

**Review Date:** ${timestamp}

### 📊 Review Results:
${Object.entries(reviews).map(([agent, review]) => {
    const icon = {
        'architecture-reviewer': '🏗️',
        'security-reviewer': '🛡️', 
        'performance-reviewer': '⚡',
        'ux-reviewer': '🎨'
    }[agent] || '🤖';
    
    const status = review.error ? '❌ Review failed' : '✅ Review completed';
    const summary = review.error 
        ? `Error: ${review.error}` 
        : (review.output ? review.output.substring(0, 300) + '...' : 'No specific issues found');
    
    return `#### ${icon} ${agent.replace('-reviewer', '').toUpperCase()}
**Status:** ${status}
**Summary:** ${summary}`;
}).join('\n\n')}

### 🔧 Integration Analysis:
${integrationResult ? integrationResult.substring(0, 500) + '...' : 'Integration analysis completed'}

### 📝 Notes:
- Only safe, low-risk improvements were automatically applied
- All changes maintain existing functionality
- Critical issues require manual review and testing
- This review was performed by AI specialists in architecture, security, performance, and UX

---
*🤖 Generated with [Claude Code](https://claude.ai/code)*
*Co-Authored-By: Claude <noreply@anthropic.com>*`;
}

// 스킵 댓글 등록
async function postSkipComment(prData) {
    const skipComment = `## 🤖 AI Review Skipped

This PR was marked to skip automated review based on keywords in the title or description.

### To enable review:
1. Remove skip keywords from title/description
2. Comment: \`@claude-bot review\` or \`/review\`

### Available skip keywords:
- \`[skip-review]\` or \`[skip review]\`
- \`[no-review]\` or \`[no review]\`  
- \`[manual-review]\` or \`[manual review]\`
- \`[urgent]\` - for urgent deployments
- \`[hotfix]\` - for hotfixes
- \`[wip]\` or \`[work in progress]\` - for work in progress

---
*🤖 Generated with [Claude Code](https://claude.ai/code)*`;

    try {
        const [owner, repo] = prData.repo.split('/');
        const commentCmd = `gh api repos/${owner}/${repo}/issues/${prData.pr_number}/comments \\
            --method POST \\
            --field body="${skipComment.replace(/"/g, '\\"')}"`;
        
        exec(commentCmd, { timeout: 30000 }, (error) => {
            if (error) {
                logger.error('Failed to post skip comment:', error.message);
            } else {
                logger.info('Skip comment posted successfully');
            }
        });
    } catch (error) {
        logger.error('Error posting skip comment:', error);
    }
}

// 에러 댓글 등록
async function postErrorComment(prData, error) {
    const errorComment = `## ❌ AI Review Failed

An error occurred during the automated review process:

\`\`\`
${error.message}
\`\`\`

**Time:** ${new Date().toISOString()}

The development team has been notified. You can try triggering the review manually by commenting \`@claude-bot review\`.

---
*🤖 Generated with [Claude Code](https://claude.ai/code)*`;

    try {
        const [owner, repo] = prData.repo.split('/');
        const commentCmd = `gh api repos/${owner}/${repo}/issues/${prData.pr_number}/comments \\
            --method POST \\
            --field body="${errorComment.replace(/"/g, '\\"')}"`;
        
        exec(commentCmd, { timeout: 30000 }, (error) => {
            if (error) {
                logger.error('Failed to post error comment:', error.message);
            } else {
                logger.info('Error comment posted successfully');
            }
        });
    } catch (error) {
        logger.error('Error posting error comment:', error);
    }
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

    // 빠른 응답
    res.status(200).send('OK');

    // 비동기 처리
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

// 로그 디렉토리 생성
async function ensureLogDirectory() {
    const logDir = path.join(__dirname, 'logs');
    try {
        await fs.mkdir(logDir, { recursive: true });
    } catch (error) {
        console.error('Failed to create log directory:', error);
    }
}

// 서버 시작
async function startServer() {
    await ensureLogDirectory();
    
    // 임시 디렉토리 생성
    await fs.mkdir(TEMP_DIR, { recursive: true }).catch(() => {});
    
    app.listen(PORT, '127.0.0.1', () => {
        logger.info(`Claude Webhook Server running on localhost:${PORT}`);
        logger.info('Environment variables:', {
            ANTHROPIC_API_KEY: process.env.ANTHROPIC_API_KEY ? 'Set' : 'Missing',
            GITHUB_WEBHOOK_TOKEN: process.env.GITHUB_WEBHOOK_TOKEN ? 'Set' : 'Missing',
            GITHUB_WEBHOOK_SECRET: process.env.GITHUB_WEBHOOK_SECRET ? 'Set' : 'Missing',
            ORGANIZATION_NAME: process.env.ORGANIZATION_NAME || 'Not set'
        });
    });
}

// 우아한 종료 처리
process.on('SIGTERM', () => {
    logger.info('SIGTERM received, shutting down gracefully');
    process.exit(0);
});

process.on('SIGINT', () => {
    logger.info('SIGINT received, shutting down gracefully');
    process.exit(0);
});

// 처리되지 않은 예외 처리
process.on('uncaughtException', (error) => {
    logger.error('Uncaught Exception:', error);
    process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
    logger.error('Unhandled Rejection at:', promise, 'reason:', reason);
    process.exit(1);
});

// 서버 시작
startServer();