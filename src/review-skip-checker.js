#!/usr/bin/env node
/**
 * GitHub PR 리뷰 스킵 판단 시스템
 * 
 * PR의 내용을 분석하여 자동 AI 리뷰를 스킵할지 결정합니다.
 * 
 * 스킵 조건:
 * 1. Documentation 전용 변경사항
 * 2. 설정 파일만 변경 (package.json의 dependencies 제외)
 * 3. 매우 간단한 텍스트/번역 파일 수정
 * 4. PR 제목에 [SKIP-REVIEW] 태그 포함
 * 5. 파일 수 1개, 변경된 줄 수 5줄 이하의 trivial 변경
 */

class ReviewSkipChecker {
    constructor() {
        this.skipPatterns = {
            // 문서 및 README 파일
            documentation: [
                /^readme\.(md|txt|rst)$/i,
                /^docs?\//i,
                /\.md$/i,
                /^changelog/i,
                /^contributing/i,
                /^license/i,
                /^authors?/i,
                /^news\.(md|txt|rst)$/i
            ],
            
            // 설정 파일 (의존성 변경 제외)
            config: [
                /^\.gitignore$/,
                /^\.editorconfig$/,
                /^\.prettierrc/,
                /^\.eslintrc/,
                /^tsconfig\.json$/,
                /^jest\.config/,
                /^webpack\.config/,
                /^rollup\.config/,
                /^vite\.config/,
                /^\.env\.example$/,
                /^\.nvmrc$/,
                /^\.tool-versions$/
            ],
            
            // 간단한 텍스트/번역 파일
            trivialText: [
                /^locales?\//i,
                /^translations?\//i,
                /^i18n\//i,
                /\.po$/i,
                /\.pot$/i,
                /\.csv$/i,
                /\.txt$/i
            ]
        };
    }

    /**
     * PR 데이터를 기반으로 리뷰 스킵 여부를 판단
     * @param {Object} prData - PR 정보
     * @param {Array} changedFiles - 변경된 파일 목록
     * @returns {Object} 스킵 여부와 이유
     */
    shouldSkipReview(prData, changedFiles) {
        const checks = [
            this.checkExplicitSkipTag(prData),
            this.checkTrivialChanges(prData, changedFiles),
            this.checkDocumentationOnly(changedFiles),
            this.checkConfigOnly(changedFiles),
            this.checkTranslationOnly(changedFiles)
        ];

        const skipReasons = checks.filter(check => check.skip).map(check => check.reason);
        
        return {
            skip: skipReasons.length > 0,
            reasons: skipReasons,
            fileCount: changedFiles.length,
            totalChanges: changedFiles.reduce((sum, file) => sum + file.additions + file.deletions, 0)
        };
    }

    /**
     * PR 제목에 명시적 스킵 태그가 있는지 확인
     */
    checkExplicitSkipTag(prData) {
        const skipTags = ['[SKIP-REVIEW]', '[NO-REVIEW]', '[DOCS-ONLY]'];
        const hasSkipTag = skipTags.some(tag => prData.title.includes(tag));
        
        return {
            skip: hasSkipTag,
            reason: hasSkipTag ? '명시적 리뷰 스킵 태그 발견' : null
        };
    }

    /**
     * 매우 간단한 변경사항인지 확인
     */
    checkTrivialChanges(prData, changedFiles) {
        const totalChanges = changedFiles.reduce((sum, file) => sum + file.additions + file.deletions, 0);
        const isTrivial = changedFiles.length === 1 && totalChanges <= 5;
        
        return {
            skip: isTrivial,
            reason: isTrivial ? `매우 간단한 변경사항 (파일 1개, 변경 ${totalChanges}줄)` : null
        };
    }

    /**
     * 문서 파일만 변경되었는지 확인
     */
    checkDocumentationOnly(changedFiles) {
        const isDocumentationFile = (filename) => {
            return this.skipPatterns.documentation.some(pattern => 
                pattern.test(filename.toLowerCase())
            );
        };

        const allDocumentation = changedFiles.length > 0 && 
            changedFiles.every(file => isDocumentationFile(file.filename));
        
        return {
            skip: allDocumentation,
            reason: allDocumentation ? '문서 파일만 변경됨' : null
        };
    }

    /**
     * 설정 파일만 변경되었는지 확인 (의존성 변경 제외)
     */
    checkConfigOnly(changedFiles) {
        const isConfigFile = (filename) => {
            return this.skipPatterns.config.some(pattern => 
                pattern.test(filename.toLowerCase())
            );
        };

        const hasPackageJsonChanges = changedFiles.some(file => {
            if (file.filename.toLowerCase() === 'package.json') {
                // package.json 변경이 있다면 patch 내용을 확인해야 함
                // 실제 구현에서는 dependencies, devDependencies 섹션 변경 여부 확인
                return this.hasDependendencyChanges(file.patch || '');
            }
            return false;
        });

        if (hasPackageJsonChanges) {
            return { skip: false, reason: null };
        }

        const allConfig = changedFiles.length > 0 && 
            changedFiles.every(file => isConfigFile(file.filename));
        
        return {
            skip: allConfig,
            reason: allConfig ? '설정 파일만 변경됨 (의존성 변경 없음)' : null
        };
    }

    /**
     * 번역/다국어 파일만 변경되었는지 확인
     */
    checkTranslationOnly(changedFiles) {
        const isTranslationFile = (filename) => {
            return this.skipPatterns.trivialText.some(pattern => 
                pattern.test(filename.toLowerCase())
            );
        };

        const allTranslation = changedFiles.length > 0 && 
            changedFiles.every(file => isTranslationFile(file.filename));
        
        return {
            skip: allTranslation,
            reason: allTranslation ? '번역/텍스트 파일만 변경됨' : null
        };
    }

    /**
     * package.json에서 의존성 변경이 있는지 확인
     */
    hasDependendencyChanges(patch) {
        const dependencyPatterns = [
            /"dependencies"\s*:/,
            /"devDependencies"\s*:/,
            /"peerDependencies"\s*:/,
            /"optionalDependencies"\s*:/
        ];

        return dependencyPatterns.some(pattern => pattern.test(patch));
    }

    /**
     * 디버깅용 정보 생성
     */
    generateDebugInfo(prData, changedFiles, result) {
        return {
            pr: {
                title: prData.title,
                number: prData.number,
                author: prData.author
            },
            files: changedFiles.map(file => ({
                name: file.filename,
                additions: file.additions,
                deletions: file.deletions,
                changes: file.changes
            })),
            decision: result,
            timestamp: new Date().toISOString()
        };
    }
}

// CLI 인터페이스
if (require.main === module) {
    const checker = new ReviewSkipChecker();
    
    // 테스트 케이스
    const testCases = [
        {
            name: "Documentation only",
            prData: { title: "Update README", number: 123, author: "user" },
            files: [{ filename: "README.md", additions: 5, deletions: 2 }]
        },
        {
            name: "Skip tag explicit",
            prData: { title: "[SKIP-REVIEW] Fix typo", number: 124, author: "user" },
            files: [{ filename: "src/utils.js", additions: 1, deletions: 1 }]
        },
        {
            name: "Dependency change",
            prData: { title: "Add new library", number: 125, author: "user" },
            files: [{ filename: "package.json", additions: 1, deletions: 0, patch: '+    "lodash": "^4.17.21"' }]
        },
        {
            name: "Config only",
            prData: { title: "Update ESLint config", number: 126, author: "user" },
            files: [{ filename: ".eslintrc.json", additions: 3, deletions: 1 }]
        }
    ];
    
    console.log("🧪 리뷰 스킵 체커 테스트");
    console.log("========================");
    
    testCases.forEach(testCase => {
        const result = checker.shouldSkipReview(testCase.prData, testCase.files);
        console.log(`\n${testCase.name}:`);
        console.log(`  Skip: ${result.skip ? '✅' : '❌'}`);
        console.log(`  Reasons: ${result.reasons.join(', ') || 'None'}`);
        console.log(`  Files: ${result.fileCount}, Changes: ${result.totalChanges}`);
    });
}

module.exports = ReviewSkipChecker;