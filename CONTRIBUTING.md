# Contributing to GitHub AI Review System

🎉 First off, thanks for taking the time to contribute!

## 🚀 Quick Start for Contributors

1. **Fork** the repository
2. **Clone** your fork: `git clone https://github.com/your-username/github-ai-review-system.git`
3. **Install** dependencies: `npm install`
4. **Create** a branch: `git checkout -b feature/amazing-feature`
5. **Make** your changes
6. **Test** your changes: `./scripts/test-system.sh`
7. **Commit** your changes: `git commit -m 'Add some amazing feature'`
8. **Push** to the branch: `git push origin feature/amazing-feature`
9. **Open** a Pull Request

## 🤝 How Can I Contribute?

### 🐛 Reporting Bugs

Before creating bug reports, please check the issue list as you might find that the bug has already been reported.

**Great Bug Reports** tend to have:
- **Quick summary** and/or background
- **Steps to reproduce** - be specific!
- **What you expected** would happen
- **What actually happens**
- **Sample code** if applicable
- **Notes** (possibly including why you think this might be happening)

### 💡 Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List some examples** of how the enhancement would be used

### 🔧 Code Contributions

#### SubAgent Improvements
- Enhance existing reviewers (security, architecture, performance, UX)
- Add new specialized reviewers
- Improve review accuracy and suggestions

#### Core Features
- Webhook processing optimizations
- Smart skip logic enhancements
- Auto-fix safety improvements
- Monitoring and logging features

#### Developer Experience
- Better error messages
- Improved setup scripts
- Enhanced documentation
- Testing framework improvements

## 📋 Development Guidelines

### Code Style
- Follow existing code patterns
- Use meaningful variable and function names
- Add comments for complex logic
- Keep functions small and focused

### Testing
- Test your changes with `./scripts/test-system.sh`
- Create test PRs to verify AI review functionality
- Ensure all scripts work correctly

### Commit Messages
Follow the [Conventional Commits](https://conventionalcommits.org/) format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Maintenance tasks

Examples:
```
feat(security): add SQL injection detection
fix(webhook): handle malformed payloads gracefully  
docs(readme): add troubleshooting section
```

## 🏗️ Architecture Overview

```
src/
├── webhook-server.js       # Main webhook server
├── review-skip-checker.js  # Smart skip logic
└── subagents/              # Future: SubAgent modules

scripts/
├── setup-*.sh             # Setup and configuration
├── test-system.sh          # System testing
└── monitoring/             # Monitoring tools
```

### Key Components

1. **Webhook Server** (`webhook-server.js`)
   - Receives GitHub webhooks
   - Orchestrates SubAgent reviews
   - Manages auto-fixes and comments

2. **Review Skip Checker** (`review-skip-checker.js`)
   - Analyzes PRs for skip conditions
   - Prevents unnecessary reviews

3. **SubAgent Integration**
   - Uses Claude Code with @ mentions
   - Parallel execution of 4 specialized reviewers
   - JSON response parsing and validation

## 🧪 Testing Your Changes

### Local Testing
```bash
# Full system test
./scripts/test-system.sh

# Start server locally
./scripts/start-webhook-server.sh

# Test specific components
npm test  # (if tests exist)
```

### Integration Testing
1. Create a test PR in your organization
2. Monitor logs: `tail -f logs/webhook-server.log`
3. Verify review comments are posted
4. Check auto-fixes are applied correctly

## 📚 Documentation

- Update README.md for user-facing changes
- Add inline comments for complex code
- Update CONTRIBUTING.md for contributor workflow changes
- Include examples in documentation

## 🚨 Security Considerations

- **Never commit** tokens, secrets, or credentials
- **Use environment variables** for sensitive data
- **Validate inputs** from external sources
- **Follow security best practices** for webhook handling
- **Test security features** thoroughly

## 🔍 Code Review Process

1. **Automated Review**: Your PR will be reviewed by the AI system itself! 🤖
2. **Maintainer Review**: A project maintainer will review your changes
3. **Testing**: Ensure your changes don't break existing functionality
4. **Documentation**: Verify documentation is updated if needed

## 🆘 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **Discussions**: For questions and community support
- **Documentation**: Check README.md and code comments

## 🏷️ Issue Labels

- `bug`: Something isn't working
- `enhancement`: New feature or request  
- `documentation`: Improvements to docs
- `good first issue`: Good for newcomers
- `help wanted`: Extra attention needed
- `security`: Security-related issues

## 🎯 Roadmap

### Short Term
- [ ] Improve SubAgent prompts
- [ ] Add more auto-fix patterns
- [ ] Enhanced error handling
- [ ] Performance optimizations

### Medium Term  
- [ ] Custom reviewer configuration
- [ ] Multi-language support
- [ ] Advanced skip logic
- [ ] Metrics and analytics

### Long Term
- [ ] Web dashboard
- [ ] Plugin system
- [ ] Machine learning improvements
- [ ] Enterprise features

## 📜 Code of Conduct

- **Be respectful** and inclusive
- **Focus on constructive feedback**
- **Help others learn and grow**
- **Follow the Golden Rule**: treat others as you'd like to be treated

## 🙏 Recognition

All contributors will be recognized in our README.md file and release notes.

Thank you for contributing to GitHub AI Review System! 🚀