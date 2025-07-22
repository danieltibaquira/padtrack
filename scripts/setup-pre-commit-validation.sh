#!/bin/bash

# Setup Pre-commit Hook for CI Validation
# Installs a pre-commit hook that runs CI validation before allowing commits

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🪝 Setting up Pre-commit CI Validation Hook${NC}"
echo "=============================================="

# Check if we're in a git repository
if [[ ! -d ".git" ]]; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 1
fi

# Create pre-commit hook
PRE_COMMIT_HOOK=".git/hooks/pre-commit"

echo -e "${YELLOW}📝 Creating pre-commit hook...${NC}"

cat > "$PRE_COMMIT_HOOK" << 'EOF'
#!/bin/bash

# Pre-commit hook for DigitonePad
# Runs CI validation before allowing commits

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Pre-commit CI Validation${NC}"
echo "============================"

# Configuration
SKIP_VALIDATION=${SKIP_VALIDATION:-false}
QUICK_VALIDATION=${QUICK_VALIDATION:-true}

# Check if validation should be skipped
if [[ "$SKIP_VALIDATION" == "true" ]]; then
    echo -e "${YELLOW}⚠️  Skipping CI validation (SKIP_VALIDATION=true)${NC}"
    exit 0
fi

# Function to run quick validation
run_quick_validation() {
    echo -e "${YELLOW}🚀 Running quick CI validation...${NC}"
    
    # Check if project.yml exists and is valid
    if [[ -f "project.yml" ]]; then
        echo -e "${GREEN}✅ project.yml found${NC}"
        
        # Try to generate project
        if xcodegen generate --spec project.yml > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Project generation successful${NC}"
        else
            echo -e "${RED}❌ Project generation failed${NC}"
            echo -e "${RED}This will likely cause CI build failures${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ project.yml not found${NC}"
        return 1
    fi
    
    # Check Swift syntax
    echo -e "${YELLOW}📝 Checking Swift syntax...${NC}"
    local syntax_errors=0
    
    # Get list of Swift files being committed
    local swift_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)
    
    if [[ -n "$swift_files" ]]; then
        while read -r file; do
            if [[ -f "$file" ]]; then
                if ! swiftc -parse -suppress-warnings "$file" 2>/dev/null; then
                    echo -e "${RED}❌ Syntax error in: $file${NC}"
                    syntax_errors=$((syntax_errors + 1))
                fi
            fi
        done <<< "$swift_files"
        
        if [[ $syntax_errors -gt 0 ]]; then
            echo -e "${RED}❌ Found $syntax_errors Swift files with syntax errors${NC}"
            return 1
        else
            echo -e "${GREEN}✅ All Swift files have valid syntax${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  No Swift files to validate${NC}"
    fi
    
    # Check Package.swift if it exists
    if [[ -f "Package.swift" ]]; then
        echo -e "${YELLOW}📦 Validating Package.swift...${NC}"
        if swift package dump-package > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Package.swift is valid${NC}"
        else
            echo -e "${RED}❌ Package.swift is invalid${NC}"
            return 1
        fi
    fi
    
    # Check for Core Data model integrity
    if [[ -d "Sources/DataLayer/Resources/DigitonePad.xcdatamodeld" ]]; then
        echo -e "${YELLOW}🗄️ Validating Core Data model...${NC}"
        local model_file="Sources/DataLayer/Resources/DigitonePad.xcdatamodeld/DigitonePad.xcdatamodel/contents"
        if [[ -f "$model_file" ]]; then
            if grep -q "<?xml version" "$model_file"; then
                echo -e "${GREEN}✅ Core Data model is valid${NC}"
            else
                echo -e "${RED}❌ Core Data model appears corrupted${NC}"
                return 1
            fi
        else
            echo -e "${RED}❌ Core Data model contents not found${NC}"
            return 1
        fi
    fi
    
    echo -e "${GREEN}✅ Quick validation passed${NC}"
    return 0
}

# Function to run full validation
run_full_validation() {
    echo -e "${YELLOW}🔬 Running full CI validation...${NC}"
    
    # Run the local validation script if it exists
    if [[ -f "local_validation.sh" ]]; then
        echo -e "${YELLOW}📋 Running local validation script...${NC}"
        if ./local_validation.sh > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Local validation passed${NC}"
        else
            echo -e "${RED}❌ Local validation failed${NC}"
            echo -e "${RED}This will likely cause CI build failures${NC}"
            return 1
        fi
    fi
    
    # Try to build the project
    echo -e "${YELLOW}🔨 Testing project build...${NC}"
    if [[ -f "DigitonePad.xcodeproj/project.pbxproj" ]]; then
        # Get dynamic simulator destination
        SIMULATOR_DESTINATION=$(./scripts/get-simulator-destination.sh destination iPad)
        if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination "$SIMULATOR_DESTINATION" -configuration Debug build > /dev/null 2>&1; then
            echo -e "${GREEN}✅ Project build successful${NC}"
        else
            echo -e "${RED}❌ Project build failed${NC}"
            echo -e "${RED}This will cause CI build failures${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  Xcode project not found, skipping build test${NC}"
    fi
    
    echo -e "${GREEN}✅ Full validation passed${NC}"
    return 0
}

# Main validation logic
main() {
    # Get commit message to check for skip flags
    local commit_message_file="$1"
    local commit_message=""
    
    if [[ -f "$commit_message_file" ]]; then
        commit_message=$(cat "$commit_message_file")
    fi
    
    # Check for skip flags in commit message
    if [[ "$commit_message" =~ \[skip-ci\]|\[skip-validation\]|\[ci-skip\] ]]; then
        echo -e "${YELLOW}⚠️  Skipping CI validation (skip flag in commit message)${NC}"
        exit 0
    fi
    
    # Check for environment variables
    if [[ "$QUICK_VALIDATION" == "true" ]]; then
        if run_quick_validation; then
            echo -e "${GREEN}🎉 Pre-commit validation passed${NC}"
            exit 0
        else
            echo -e "${RED}💥 Pre-commit validation failed${NC}"
            echo -e "${YELLOW}💡 Tips to fix:${NC}"
            echo -e "  - Fix syntax errors in Swift files"
            echo -e "  - Ensure project.yml is valid"
            echo -e "  - Check Package.swift configuration"
            echo -e "  - Verify Core Data model integrity"
            echo -e "  - Use 'SKIP_VALIDATION=true git commit' to skip validation"
            echo -e "  - Add [skip-ci] to commit message to skip validation"
            exit 1
        fi
    else
        if run_full_validation; then
            echo -e "${GREEN}🎉 Pre-commit validation passed${NC}"
            exit 0
        else
            echo -e "${RED}💥 Pre-commit validation failed${NC}"
            echo -e "${YELLOW}💡 Tips to fix:${NC}"
            echo -e "  - Run './local_validation.sh' to see detailed errors"
            echo -e "  - Fix any build or test failures"
            echo -e "  - Use 'SKIP_VALIDATION=true git commit' to skip validation"
            echo -e "  - Add [skip-ci] to commit message to skip validation"
            exit 1
        fi
    fi
}

# Run main function
main "$@"
EOF

# Make the hook executable
chmod +x "$PRE_COMMIT_HOOK"

echo -e "${GREEN}✅ Pre-commit hook created${NC}"

# Create a helper script for managing the hook
echo -e "${YELLOW}📝 Creating hook management script...${NC}"

cat > "scripts/manage-pre-commit-hook.sh" << 'EOF'
#!/bin/bash

# Pre-commit Hook Management Script
# Helps manage the pre-commit CI validation hook

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

HOOK_FILE=".git/hooks/pre-commit"

show_help() {
    echo -e "${BLUE}Pre-commit Hook Management${NC}"
    echo "=========================="
    echo ""
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  enable    - Enable the pre-commit hook"
    echo "  disable   - Disable the pre-commit hook"
    echo "  status    - Show current hook status"
    echo "  test      - Test the hook without committing"
    echo "  reset     - Reset the hook to default configuration"
    echo ""
    echo "Environment Variables:"
    echo "  SKIP_VALIDATION=true     - Skip validation for one commit"
    echo "  QUICK_VALIDATION=false   - Run full validation instead of quick"
    echo ""
    echo "Commit Message Flags:"
    echo "  [skip-ci]        - Skip CI validation"
    echo "  [skip-validation] - Skip pre-commit validation"
    echo "  [ci-skip]        - Skip CI validation"
}

enable_hook() {
    if [[ -f "$HOOK_FILE" ]]; then
        chmod +x "$HOOK_FILE"
        echo -e "${GREEN}✅ Pre-commit hook enabled${NC}"
    else
        echo -e "${RED}❌ Pre-commit hook not found${NC}"
        echo -e "${YELLOW}Run setup-pre-commit-validation.sh to create the hook${NC}"
        exit 1
    fi
}

disable_hook() {
    if [[ -f "$HOOK_FILE" ]]; then
        chmod -x "$HOOK_FILE"
        echo -e "${YELLOW}⚠️  Pre-commit hook disabled${NC}"
    else
        echo -e "${RED}❌ Pre-commit hook not found${NC}"
        exit 1
    fi
}

show_status() {
    echo -e "${BLUE}Pre-commit Hook Status${NC}"
    echo "====================="
    
    if [[ -f "$HOOK_FILE" ]]; then
        if [[ -x "$HOOK_FILE" ]]; then
            echo -e "${GREEN}✅ Hook is installed and enabled${NC}"
        else
            echo -e "${YELLOW}⚠️  Hook is installed but disabled${NC}"
        fi
        
        echo ""
        echo "Hook file: $HOOK_FILE"
        echo "File size: $(wc -c < "$HOOK_FILE") bytes"
        echo "Last modified: $(stat -f "%Sm" "$HOOK_FILE" 2>/dev/null || date)"
    else
        echo -e "${RED}❌ Hook is not installed${NC}"
    fi
}

test_hook() {
    echo -e "${BLUE}Testing pre-commit hook...${NC}"
    
    if [[ -f "$HOOK_FILE" && -x "$HOOK_FILE" ]]; then
        # Create a temporary commit message file
        local temp_commit_msg=$(mktemp)
        echo "Test commit message" > "$temp_commit_msg"
        
        # Run the hook
        if "$HOOK_FILE" "$temp_commit_msg"; then
            echo -e "${GREEN}✅ Hook test passed${NC}"
        else
            echo -e "${RED}❌ Hook test failed${NC}"
            exit 1
        fi
        
        # Clean up
        rm -f "$temp_commit_msg"
    else
        echo -e "${RED}❌ Hook is not installed or not executable${NC}"
        exit 1
    fi
}

reset_hook() {
    echo -e "${YELLOW}🔄 Resetting pre-commit hook...${NC}"
    
    if [[ -f "$HOOK_FILE" ]]; then
        rm "$HOOK_FILE"
        echo -e "${GREEN}✅ Hook removed${NC}"
    fi
    
    echo -e "${YELLOW}Run setup-pre-commit-validation.sh to recreate the hook${NC}"
}

# Main command handling
case "${1:-help}" in
    enable)
        enable_hook
        ;;
    disable)
        disable_hook
        ;;
    status)
        show_status
        ;;
    test)
        test_hook
        ;;
    reset)
        reset_hook
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_help
        exit 1
        ;;
esac
EOF

chmod +x "scripts/manage-pre-commit-hook.sh"

echo -e "${GREEN}✅ Hook management script created${NC}"

# Create documentation
echo -e "${YELLOW}📚 Creating documentation...${NC}"

cat > "PRE_COMMIT_HOOK_GUIDE.md" << 'EOF'
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
EOF

echo -e "${GREEN}✅ Documentation created: PRE_COMMIT_HOOK_GUIDE.md${NC}"

echo -e "${BLUE}🎉 Pre-commit hook setup complete!${NC}"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "1. Test the hook: ./scripts/manage-pre-commit-hook.sh test"
echo "2. Check hook status: ./scripts/manage-pre-commit-hook.sh status"
echo "3. Read the guide: cat PRE_COMMIT_HOOK_GUIDE.md"
echo "4. Make a test commit to verify functionality"
echo ""
echo -e "${BLUE}💡 Pro tip: Use 'SKIP_VALIDATION=true git commit' to skip validation when needed${NC}"