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
