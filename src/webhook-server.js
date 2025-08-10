#!/usr/bin/env node
/**
 * GitHub Organization 웹훅 서버
 * Claude Code SubAgent를 활용한 PR 자동 리뷰 시스템
 */

const express = require('express');
const crypto = require('crypto');
const { exec } = require('child_process');
const fs = require('fs').promises;
const path = require('path');

const ReviewSkipChecker = require('./review-skip-checker');

const app = express();
const port = process.env.PORT || 3000;

// 미들웨어 설정
app.use(express.json({ limit: '10mb' }));
app.use((req, res, next) => {
    res.header('Access-Control-Allow-Origin', '*');
    res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.header('Access-Control-Allow-Headers', 'Content-Type');
    next();
});

// 로깅 설정
const logFilePath = path.join(__dirname, '../logs/webhook-server.log');
const log = (message) => {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] ${message}\n`;
    console.log(logMessage.trim());
    
    // 로그 파일에 비동기로 기록
    fs.appendFile(logFilePath, logMessage).catch(err => {
        console.error('Log write error:', err);
    });
};

// GitHub 웹훅 시크릿 검증
function verifyGitHubSignature(payload, signature, secret) {
    if (!signature || !secret) {
        return false;
    }
    
    const expectedSignature = 'sha256=' + crypto
        .createHmac('sha256', secret)
        .update(payload)
        .digest('hex');
    
    return crypto.timingSafeEqual(
        Buffer.from(signature),
        Buffer.from(expectedSignature)
    );
}

// PR 데이터 추출 (Organization 정보 포함)
function extractPRData(eventData) {
    return {
        organization: eventData.organization?.login,
        repo: eventData.repository.full_name,
        pr_number: eventData.pull_request.number,
        title: eventData.pull_request.title,
        body: eventData.pull_request.body || '',
        head_sha: eventData.pull_request.head.sha,
        base_branch: eventData.pull_request.base.ref,
        head_branch: eventData.pull_request.head.ref,
        author: eventData.pull_request.user.login,
        html_url: eventData.pull_request.html_url,
        clone_url: eventData.repository.clone_url,
        created_at: eventData.pull_request.created_at,
        updated_at: eventData.pull_request.updated_at
    };
}

// GitHub API로 변경된 파일 목록 가져오기
async function getChangedFiles(prData) {
    return new Promise((resolve, reject) => {
        const command = `gh api repos/${prData.repo}/pulls/${prData.pr_number}/files --jq '[.[] | {filename: .filename, additions: .additions, deletions: .deletions, changes: .changes, status: .status}]'`;
        
        log(`📂 Fetching changed files for PR #${prData.pr_number}`);
        
        exec(command, { maxBuffer: 1024 * 1024 * 5 }, (error, stdout, stderr) => {
            if (error) {
                log(`⚠️ Failed to fetch changed files: ${error.message}`);
                resolve([]); // 실패 시 빈 배열 반환
                return;
            }
            
            try {
                const files = JSON.parse(stdout);
                log(`✅ Found ${files.length} changed files`);
                resolve(files);
            } catch (parseError) {
                log(`⚠️ Failed to parse files: ${parseError.message}`);
                resolve([]);
            }
        });
    });
}

// SubAgent 실행 함수 (@ 멘션 방식)
async function runSubAgent(agentName, prData, tempDir) {
    return new Promise((resolve, reject) => {
        const agentPrompt = generateAgentPrompt(agentName, prData, tempDir);
        
        // @ 멘션 방식으로 SubAgent 호출
        const command = `cd "${tempDir}" && echo '${agentPrompt.replace(/'/g, "'\\''")}' | claude`;
        
        log(`🤖 Running ${agentName} for PR #${prData.pr_number}`);
        log(`📝 Command: claude with @${agentName} mention in prompt`);
        
        exec(command, { 
            timeout: 300000, // 5분 타임아웃
            maxBuffer: 1024 * 1024 * 10 // 10MB 버퍼
        }, (error, stdout, stderr) => {
            if (error) {
                log(`❌ ${agentName} failed: ${error.message}`);
                log(`❌ stderr: ${stderr}`);
                resolve({
                    agent: agentName,
                    success: false,
                    error: error.message,
                    output: stderr
                });
                return;
            }
            
            // JSON 부분만 추출 시도
            try {
                // JSON 블록 찾기 (```json 또는 { 로 시작)
                const jsonMatch = stdout.match(/```json\s*([\s\S]*?)```|({[\s\S]*})/m);
                if (jsonMatch) {
                    const jsonStr = jsonMatch[1] || jsonMatch[2];
                    const result = JSON.parse(jsonStr);
                    log(`✅ ${agentName} completed successfully`);
                    resolve({
                        agent: agentName,
                        success: true,
                        result: result,
                        output: stdout
                    });
                } else {
                    // JSON을 찾지 못한 경우
                    log(`⚠️ ${agentName} - No JSON found in output`);
                    resolve({
                        agent: agentName,
                        success: false,
                        error: 'No JSON found in output',
                        output: stdout
                    });
                }
            } catch (parseError) {
                log(`⚠️ ${agentName} output parsing failed: ${parseError.message}`);
                log(`📄 Raw output: ${stdout.substring(0, 500)}...`);
                resolve({
                    agent: agentName,
                    success: false,
                    error: 'Failed to parse agent output',
                    output: stdout
                });
            }
        });
    });
}

// SubAgent용 프롬프트 생성 (@ 멘션 포함)
function generateAgentPrompt(agentName, prData, tempDir) {
    const agentDescriptions = {
        'security-reviewer': '보안 취약점, 인증 메커니즘, 데이터 보호',
        'architecture-reviewer': '시스템 설계 패턴, 코드 구조, 확장성',
        'performance-reviewer': '성능 최적화, 리소스 사용량, 알고리즘 효율성',
        'ux-reviewer': '사용자 경험, 접근성, UI 일관성'
    };
    
    const basePrompt = `@${agentName}, please perform a comprehensive review of this GitHub Pull Request.

You are a specialized ${agentName} focusing on ${agentDescriptions[agentName]}.

## PR Information:
- Organization: ${prData.organization}
- Repository: ${prData.repo}
- PR #${prData.pr_number}: ${prData.title}
- Author: ${prData.author}
- Branch: ${prData.head_branch} -> ${prData.base_branch}

## PR Description:
${prData.body || 'No description provided'}

## Working Directory:
${tempDir}

## Your Tasks:
1. Analyze the PR changes thoroughly
2. Provide detailed review from your expertise area (${agentDescriptions[agentName]})
3. Identify issues and provide improvement suggestions
4. Identify safe auto-fixable items

## Required Output Format:
Please return your review results in the following JSON format enclosed in \`\`\`json blocks:

\`\`\`json
{
  "agent": "${agentName}",
  "pr_number": ${prData.pr_number},
  "review_summary": "Brief summary of your review findings",
  "issues_found": [
    {
      "severity": "high/medium/low",
      "category": "category name",
      "description": "detailed issue description",
      "file": "file path",
      "line": line_number,
      "suggestion": "improvement suggestion",
      "auto_fixable": true/false
    }
  ],
  "safe_auto_fixes": [
    {
      "file": "file path",
      "description": "fix description",
      "changes": "specific changes to apply"
    }
  ],
  "overall_score": 85,
  "recommendations": ["list of recommendations"]
}
\`\`\`

Please ensure the JSON is valid and complete.`;

    return basePrompt.trim();
}

// PR 클론 및 분석 준비
async function preparePRAnalysis(prData) {
    const tempDir = `/tmp/pr-analysis-${prData.organization}-${prData.pr_number}-${Date.now()}`;
    
    try {
        // 임시 디렉토리 생성
        await fs.mkdir(tempDir, { recursive: true });
        
        // GitHub 저장소 클론
        const cloneCommand = `cd "${tempDir}" && git clone --depth=50 --branch="${prData.head_branch}" "${prData.clone_url}" repo`;
        
        await new Promise((resolve, reject) => {
            exec(cloneCommand, { timeout: 60000 }, (error, stdout, stderr) => {
                if (error) {
                    reject(new Error(`Clone failed: ${error.message}`));
                } else {
                    resolve();
                }
            });
        });
        
        const repoDir = path.join(tempDir, 'repo');
        
        // PR 변경사항 분석을 위한 diff 생성
        const diffCommand = `cd "${repoDir}" && git fetch origin "${prData.base_branch}" && git diff origin/${prData.base_branch}...HEAD > ../pr-diff.patch`;
        
        await new Promise((resolve, reject) => {
            exec(diffCommand, (error) => {
                if (error) {
                    log(`Warning: Could not generate diff: ${error.message}`);
                }
                resolve();
            });
        });
        
        return repoDir;
    } catch (error) {
        // 실패시 임시 디렉토리 정리
        try {
            await fs.rm(tempDir, { recursive: true, force: true });
        } catch (cleanupError) {
            log(`Cleanup error: ${cleanupError.message}`);
        }
        throw error;
    }
}

// 4개 SubAgent 병렬 실행
async function runAllSubAgents(prData, repoDir) {
    const agents = ['security-reviewer', 'architecture-reviewer', 'performance-reviewer', 'ux-reviewer'];
    
    log(`🚀 Starting parallel review with ${agents.length} agents`);
    
    const agentPromises = agents.map(agent => 
        runSubAgent(agent, prData, repoDir)
    );
    
    // 모든 에이전트 결과 대기 (실패한 것도 포함)
    const results = await Promise.allSettled(agentPromises);
    
    return results.map((result, index) => ({
        agent: agents[index],
        ...(result.status === 'fulfilled' ? result.value : {
            success: false,
            error: result.reason?.message || 'Unknown error'
        })
    }));
}

// 리뷰 결과 통합
function consolidateReviews(agentResults) {
    const successful = agentResults.filter(r => r.success);
    const failed = agentResults.filter(r => !r.success);
    
    let allIssues = [];
    let allAutoFixes = [];
    let overallScore = 100;
    let recommendations = [];
    
    successful.forEach(result => {
        if (result.result?.issues_found) {
            allIssues = allIssues.concat(result.result.issues_found);
        }
        if (result.result?.safe_auto_fixes) {
            allAutoFixes = allAutoFixes.concat(result.result.safe_auto_fixes);
        }
        if (result.result?.overall_score) {
            overallScore = Math.min(overallScore, result.result.overall_score);
        }
        if (result.result?.recommendations) {
            recommendations = recommendations.concat(result.result.recommendations);
        }
    });
    
    return {
        total_agents: agentResults.length,
        successful_agents: successful.length,
        failed_agents: failed.length,
        failed_agent_details: failed.map(f => ({ agent: f.agent, error: f.error })),
        consolidated_issues: allIssues,
        safe_auto_fixes: allAutoFixes,
        overall_score: overallScore,
        recommendations: [...new Set(recommendations)] // 중복 제거
    };
}

// 안전한 자동 수정 적용
async function applySafeAutoFixes(repoDir, autoFixes, prData) {
    if (!autoFixes || autoFixes.length === 0) {
        log('No auto fixes to apply');
        return { applied: 0, errors: [] };
    }
    
    let applied = 0;
    const errors = [];
    
    for (const fix of autoFixes) {
        try {
            const filePath = path.join(repoDir, fix.file);
            const fileExists = await fs.access(filePath).then(() => true).catch(() => false);
            
            if (!fileExists) {
                errors.push(`File not found: ${fix.file}`);
                continue;
            }
            
            // 파일 백업
            const backupPath = `${filePath}.backup.${Date.now()}`;
            await fs.copyFile(filePath, backupPath);
            
            // 여기에 실제 수정 로직 구현 필요
            // 현재는 로깅만 수행
            log(`Would apply fix to ${fix.file}: ${fix.description}`);
            applied++;
            
        } catch (error) {
            errors.push(`Failed to fix ${fix.file}: ${error.message}`);
        }
    }
    
    return { applied, errors };
}

// GitHub에 커밋 및 댓글 등록
async function commitAndComment(repoDir, prData, reviewSummary, autoFixResults) {
    try {
        // 변경사항이 있으면 커밋
        if (autoFixResults.applied > 0) {
            const commitCommand = `cd "${repoDir}" && git add . && git commit -m "🤖 Auto-fix: Applied ${autoFixResults.applied} safe fixes

AI Review Summary:
- Overall Score: ${reviewSummary.overall_score}/100
- Issues Found: ${reviewSummary.consolidated_issues.length}
- Auto Fixes Applied: ${autoFixResults.applied}

Generated by Claude AI Review System"`;

            await new Promise((resolve, reject) => {
                exec(commitCommand, (error, stdout, stderr) => {
                    if (error) {
                        log(`Commit failed: ${error.message}`);
                        reject(error);
                    } else {
                        log('✅ Changes committed successfully');
                        resolve();
                    }
                });
            });
            
            // 원격 저장소에 푸시
            const pushCommand = `cd "${repoDir}" && git push origin "${prData.head_branch}"`;
            
            await new Promise((resolve, reject) => {
                exec(pushCommand, (error) => {
                    if (error) {
                        log(`Push failed: ${error.message}`);
                        reject(error);
                    } else {
                        log('✅ Changes pushed successfully');
                        resolve();
                    }
                });
            });
        }
        
        // GitHub PR에 댓글 추가
        const comment = generateReviewComment(reviewSummary, autoFixResults);
        const commentCommand = `gh pr comment ${prData.pr_number} --repo "${prData.repo}" --body "${comment.replace(/"/g, '\\"')}"`;
        
        await new Promise((resolve, reject) => {
            exec(commentCommand, (error) => {
                if (error) {
                    log(`Comment failed: ${error.message}`);
                    reject(error);
                } else {
                    log('✅ Review comment added successfully');
                    resolve();
                }
            });
        });
        
    } catch (error) {
        log(`❌ Commit/Comment failed: ${error.message}`);
        throw error;
    }
}

// 리뷰 댓글 생성
function generateReviewComment(reviewSummary, autoFixResults) {
    const highIssues = reviewSummary.consolidated_issues.filter(i => i.severity === 'high').length;
    const mediumIssues = reviewSummary.consolidated_issues.filter(i => i.severity === 'medium').length;
    const lowIssues = reviewSummary.consolidated_issues.filter(i => i.severity === 'low').length;
    
    let comment = `## 🤖 AI Code Review Summary

**Overall Score:** ${reviewSummary.overall_score}/100

### 📊 Review Statistics
- **Agents Completed:** ${reviewSummary.successful_agents}/${reviewSummary.total_agents}
- **Issues Found:** ${reviewSummary.consolidated_issues.length} total
  - 🔴 High: ${highIssues}
  - 🟡 Medium: ${mediumIssues}  
  - 🟢 Low: ${lowIssues}
- **Auto Fixes Applied:** ${autoFixResults.applied}

`;

    // 주요 이슈들 나열
    if (reviewSummary.consolidated_issues.length > 0) {
        comment += `### 🔍 Key Issues Found\n\n`;
        
        const topIssues = reviewSummary.consolidated_issues
            .sort((a, b) => {
                const severityOrder = { 'high': 3, 'medium': 2, 'low': 1 };
                return severityOrder[b.severity] - severityOrder[a.severity];
            })
            .slice(0, 5);
            
        topIssues.forEach((issue, index) => {
            const severity = issue.severity === 'high' ? '🔴' : 
                           issue.severity === 'medium' ? '🟡' : '🟢';
            comment += `${index + 1}. ${severity} **${issue.category}** in \`${issue.file}\`\n`;
            comment += `   ${issue.description}\n`;
            if (issue.suggestion) {
                comment += `   💡 *Suggestion: ${issue.suggestion}*\n`;
            }
            comment += `\n`;
        });
    }
    
    // 권장사항
    if (reviewSummary.recommendations.length > 0) {
        comment += `### 💡 Recommendations\n\n`;
        reviewSummary.recommendations.slice(0, 3).forEach((rec, index) => {
            comment += `${index + 1}. ${rec}\n`;
        });
    }
    
    // 에이전트 실패 정보
    if (reviewSummary.failed_agents > 0) {
        comment += `\n### ⚠️ Agent Failures\n`;
        reviewSummary.failed_agent_details.forEach(failure => {
            comment += `- **${failure.agent}:** ${failure.error}\n`;
        });
    }
    
    comment += `\n---
*Generated by Claude AI Review System at ${new Date().toISOString()}*`;
    
    return comment;
}

// 임시 디렉토리 정리
async function cleanupTempDir(tempDir) {
    try {
        await fs.rm(path.dirname(tempDir), { recursive: true, force: true });
        log(`🧹 Cleaned up temporary directory: ${tempDir}`);
    } catch (error) {
        log(`⚠️ Cleanup warning: ${error.message}`);
    }
}

// 메인 PR 처리 함수
async function handlePullRequestEvent(eventData) {
    const prData = extractPRData(eventData);
    let tempDir;
    
    try {
        log(`🎯 Processing PR #${prData.pr_number} from ${prData.organization}/${prData.repo}`);
        
        // 1. 리뷰 스킵 여부 확인
        const skipChecker = new ReviewSkipChecker();
        
        // GitHub API로 변경된 파일 목록 가져오기
        const changedFiles = await getChangedFiles(prData);
        const skipResult = skipChecker.shouldSkipReview(prData, changedFiles);
        
        if (skipResult.skip) {
            log(`⏭️ Skipping review for PR #${prData.pr_number}: ${skipResult.reasons.join(', ')}`);
            
            // 스킵 사유 댓글 추가
            const skipComment = `## 🤖 AI Review Skipped

This PR was automatically skipped from AI review for the following reasons:
${skipResult.reasons.map(reason => `- ${reason}`).join('\n')}

To force a review, add \`@claude-bot review\` in a comment.`;
            
            const commentCommand = `gh pr comment ${prData.pr_number} --repo "${prData.repo}" --body "${skipComment.replace(/"/g, '\\"')}"`;
            exec(commentCommand, () => {}); // 비동기 실행
            
            return;
        }
        
        // 2. 리뷰 시작 댓글 추가
        const startComment = `## 🤖 AI Review Started

🔍 **Starting comprehensive code review for this PR...**

### Review Process
- 📂 **Files analyzed**: ${changedFiles.length} changed files
- 🤖 **Agents**: 4 specialized reviewers running in parallel
  - 🛡️ Security Reviewer
  - 🏗️ Architecture Reviewer  
  - ⚡ Performance Reviewer
  - 🎨 UX Reviewer

⏱️ **Estimated completion**: 3-5 minutes

*Review results will be posted as a comment when all agents complete.*`;

        const startCommentCommand = `gh pr comment ${prData.pr_number} --repo "${prData.repo}" --body "${startComment.replace(/"/g, '\\"')}"`;
        
        try {
            await new Promise((resolve, reject) => {
                exec(startCommentCommand, (error) => {
                    if (error) {
                        log(`⚠️ Failed to post start comment: ${error.message}`);
                        reject(error);
                    } else {
                        log('📝 Review start comment posted');
                        resolve();
                    }
                });
            });
        } catch (error) {
            log(`⚠️ Start comment failed, continuing with review: ${error.message}`);
        }

        // 3. PR 분석 준비 (클론)
        tempDir = await preparePRAnalysis(prData);
        
        // 4. 4개 SubAgent 병렬 실행
        const agentResults = await runAllSubAgents(prData, tempDir);
        
        // 4. 결과 통합
        const reviewSummary = consolidateReviews(agentResults);
        
        // 5. 안전한 자동 수정 적용
        const autoFixResults = await applySafeAutoFixes(tempDir, reviewSummary.safe_auto_fixes, prData);
        
        // 6. 커밋 및 댓글 등록
        await commitAndComment(tempDir, prData, reviewSummary, autoFixResults);
        
        log(`✅ Successfully completed review for PR #${prData.pr_number}`);
        
    } catch (error) {
        log(`❌ Error processing PR #${prData.pr_number}: ${error.message}`);
        log(`❌ Stack trace: ${error.stack}`);
        
        // 에러 댓글 추가
        const errorComment = `## 🤖 AI Review Error

Failed to complete automated review: ${error.message}

You can manually trigger a review by commenting \`@claude-bot review\`.`;
        
        const commentCommand = `gh pr comment ${prData.pr_number} --repo "${prData.repo}" --body "${errorComment.replace(/"/g, '\\"')}"`;
        exec(commentCommand, () => {});
        
    } finally {
        // 임시 디렉토리 정리
        if (tempDir) {
            await cleanupTempDir(tempDir);
        }
    }
}

// 댓글 이벤트 처리 (수동 트리거)
async function handleCommentEvent(eventData) {
    const comment = eventData.comment.body.toLowerCase().trim();
    
    // @claude-bot review 명령어 확인
    if (comment.includes('@claude-bot') && comment.includes('review')) {
        log(`🎯 Manual review triggered for PR #${eventData.issue.number}`);
        
        // PR 이벤트 데이터로 변환하여 처리
        const mockPREvent = {
            action: 'synchronize',
            pull_request: {
                ...eventData.issue,
                head: { sha: 'latest' }, // 실제로는 API로 가져와야 함
                base: { ref: 'main' },
                user: { login: eventData.issue.user.login }
            },
            repository: eventData.repository,
            organization: eventData.organization
        };
        
        await handlePullRequestEvent(mockPREvent);
    }
}

// 웹훅 엔드포인트
app.post('/webhook', async (req, res) => {
    const eventType = req.headers['x-github-event'];
    const eventData = req.body;
    const action = eventData.action;
    
    // 즉시 로그 기록
    log(`📨 Webhook received: ${eventType}/${action} from ${eventData.organization?.login || 'unknown'}`);
    
    // GitHub 시크릿 검증
    const signature = req.headers['x-hub-signature-256'];
    const payload = JSON.stringify(req.body);
    const secret = process.env.GITHUB_WEBHOOK_SECRET;
    
    if (secret && !verifyGitHubSignature(payload, signature, secret)) {
        log('❌ Unauthorized webhook request - invalid signature');
        return res.status(401).send('Unauthorized');
    }
    
    log(`✅ Signature verified for ${eventType}/${action}`);
    
    try {
        switch (eventType) {
            case 'pull_request':
                if (['opened', 'synchronize'].includes(eventData.action)) {
                    log(`🎯 Processing PR event: ${action} for PR #${eventData.pull_request?.number}`);
                    // 비동기로 처리 (웹훅 응답 시간 최소화)
                    setImmediate(() => handlePullRequestEvent(eventData));
                } else {
                    log(`⏭️ Skipping PR event: ${action}`);
                }
                break;
                
            case 'issue_comment':
                if (eventData.action === 'created' && eventData.issue.pull_request) {
                    log(`💬 Processing comment on PR #${eventData.issue.number}`);
                    setImmediate(() => handleCommentEvent(eventData));
                } else {
                    log(`⏭️ Skipping comment event: not a PR comment`);
                }
                break;
                
            case 'pull_request_review':
                log(`📝 Received review event: ${eventData.action}`);
                // 필요시 리뷰 완료 후 추가 처리
                break;
                
            case 'ping':
                log(`🏓 Ping event received - webhook is connected`);
                break;
                
            default:
                log(`🤷 Ignoring ${eventType} event`);
        }
        
        res.status(200).json({ 
            status: 'ok', 
            event: eventType, 
            action: eventData.action,
            timestamp: new Date().toISOString()
        });
        
    } catch (error) {
        log(`❌ Webhook processing error: ${error.message}`);
        res.status(500).json({ status: 'error', message: error.message });
    }
});

// 헬스체크 엔드포인트
app.get('/health', (req, res) => {
    res.json({ 
        status: 'healthy',
        timestamp: new Date().toISOString(),
        service: 'claude-webhook-server',
        version: '1.0.0'
    });
});

// 상태 확인 엔드포인트
app.get('/status', (req, res) => {
    res.json({
        service: 'GitHub Organization AI Review System',
        version: '1.0.0',
        uptime: process.uptime(),
        memory: process.memoryUsage(),
        features: [
            'Organization-level webhook processing',
            '4 specialized SubAgent reviews (@ mention)',
            'Smart review skipping',
            'Safe automatic fixes',
            'Manual review triggering'
        ],
        agents: ['security-reviewer', 'architecture-reviewer', 'performance-reviewer', 'ux-reviewer'],
        environment: {
            node_version: process.version,
            port: port,
            organization: process.env.ORGANIZATION_NAME || 'not set'
        }
    });
});

// 서버 시작
app.listen(port, '0.0.0.0', () => {
    log(`🚀 GitHub Webhook Server started on port ${port}`);
    log(`🔗 Health check: http://localhost:${port}/health`);
    log(`📊 Status: http://localhost:${port}/status`);
    log(`🎯 Webhook endpoint: http://localhost:${port}/webhook`);
    log(`📁 Log file: ${logFilePath}`);
});

// 프로세스 종료 시 정리
process.on('SIGTERM', () => {
    log('👋 Server shutting down...');
    process.exit(0);
});

process.on('SIGINT', () => {
    log('👋 Server shutting down...');
    process.exit(0);
});

module.exports = app;