# Pre-commit Hook Guide

## Overview

The pre-commit hook automatically validates your code before allowing commits, helping catch CI/CD issues early.

## Features

- **Swift Syntax Validation**: Checks all Swift files for syntax errors
- **Project Configuration**: Validates project.yml and Package.swift
- **Core Data Model**: Ensures Core Data model integrity
- **Build Testing**: Optional full build testing
- **Flexible Skipping**: Multiple ways to skip validation when needed

## Usage

### Normal Commits
```bash
git commit -m "Your commit message"
# Hook runs automatically
```

### Skip Validation
```bash
# Environment variable (one-time)
SKIP_VALIDATION=true git commit -m "Emergency fix"

# Commit message flag
git commit -m "Emergency fix [skip-ci]"
```

### Full Validation
```bash
# Run comprehensive validation
QUICK_VALIDATION=false git commit -m "Major changes"
```

## Managing the Hook

```bash
# Check hook status
./scripts/manage-pre-commit-hook.sh status

# Enable/disable hook
./scripts/manage-pre-commit-hook.sh enable
./scripts/manage-pre-commit-hook.sh disable

# Test hook without committing
./scripts/manage-pre-commit-hook.sh test

# Reset hook to default
./scripts/manage-pre-commit-hook.sh reset
```

## Skip Flags

Use these in your commit message to skip validation:
- `[skip-ci]`
- `[skip-validation]`
- `[ci-skip]`

## Environment Variables

- `SKIP_VALIDATION=true` - Skip all validation
- `QUICK_VALIDATION=false` - Run full validation instead of quick

## Troubleshooting

### Hook Not Running
1. Check if hook is executable: `ls -la .git/hooks/pre-commit`
2. Enable hook: `./scripts/manage-pre-commit-hook.sh enable`

### Validation Failing
1. Run validation manually: `./scripts/manage-pre-commit-hook.sh test`
2. Check specific errors and fix them
3. Use skip flags if needed for emergency commits

### Hook Conflicts
If you have other pre-commit tools, you may need to integrate them or modify the hook script.

## Best Practices

1. **Fix Issues Early**: Don't rely on skip flags regularly
2. **Test Locally**: Use `./local_validation.sh` for comprehensive testing
3. **Emergency Commits**: Use skip flags sparingly, fix issues in follow-up commits
4. **Team Coordination**: Ensure all team members understand the hook behavior

## Customization

The hook script is located at `.git/hooks/pre-commit` and can be customized for your specific needs.
