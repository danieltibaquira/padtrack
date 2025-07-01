#!/bin/bash

# Pre-Commit Validation Script for PadTrack
# This script validates all changes before pushing to GitHub to prevent CI failures

set -e

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
VALIDATION_LOG="/tmp/padtrack_validation_$TIMESTAMP.log"
TEMP_DIR="/tmp/padtrack_validation_$TIMESTAMP"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_header() {
    echo -e "${PURPLE}[VALIDATION]${NC} $1" | tee -a "$VALIDATION_LOG"
}

log_step() {
    echo -e "${CYAN}[STEP]${NC} $1" | tee -a "$VALIDATION_LOG"
}

# Cleanup function
cleanup() {
    rm -rf "$TEMP_DIR"
    log_info "Cleanup completed"
}

# Set up cleanup trap
trap cleanup EXIT

# Create temp directory
mkdir -p "$TEMP_DIR"

# Print header
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                          PadTrack Pre-Commit Validation                     ║"
echo "║                    Preventing CI Failures Before Push                       ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_header "Starting pre-commit validation process..."
log_info "Project Root: $PROJECT_ROOT"
log_info "Validation Log: $VALIDATION_LOG"
echo ""

# Change to project directory
cd "$PROJECT_ROOT"

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

# Test 1: Check Swift Version Compatibility
log_step "Checking Swift version compatibility..."
total_tests=$((total_tests + 1))

if command -v swift &> /dev/null; then
    swift_version=$(swift --version | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
    package_version=$(grep "swift-tools-version:" Package.swift | grep -o '[0-9]\+\.[0-9]\+')
    
    log_info "Local Swift version: $swift_version"
    log_info "Package Swift version: $package_version"
    
    # Check if local version is compatible (should be >= package version)
    if [ "$(printf '%s\n' "$package_version" "$swift_version" | sort -V | head -n1)" = "$package_version" ]; then
        log_success "Swift version compatibility: OK"
        passed_tests=$((passed_tests + 1))
    else
        log_error "Swift version incompatibility: Local $swift_version < Required $package_version"
        failed_tests=$((failed_tests + 1))
    fi
else
    log_error "Swift CLI not found"
    failed_tests=$((failed_tests + 1))
fi

# Test 2: Check for Swift 6.0 specific syntax incompatible with 5.10
log_step "Checking for Swift 6.0 incompatible syntax..."
total_tests=$((total_tests + 1))

incompatible_patterns=("@preconcurrency" "consuming" "borrowing")
incompatible_found=0

for pattern in "${incompatible_patterns[@]}"; do
    if find Sources -name "*.swift" -exec grep -l "$pattern" {} \; 2>/dev/null | head -5; then
        incompatible_found=$((incompatible_found + 1))
        log_error "Found Swift 6.0 incompatible syntax: $pattern"
    fi
done

if [ "$incompatible_found" -eq 0 ]; then
    log_success "No Swift 6.0 incompatible syntax found"
    passed_tests=$((passed_tests + 1))
else
    log_error "$incompatible_found incompatible syntax patterns found"
    failed_tests=$((failed_tests + 1))
fi

# Test 3: Package.swift Syntax Check
log_step "Validating Package.swift syntax..."
total_tests=$((total_tests + 1))

if swift package dump-package > "$TEMP_DIR/package_dump.json" 2>&1; then
    log_success "Package.swift syntax: Valid"
    passed_tests=$((passed_tests + 1))
else
    log_error "Package.swift syntax: Invalid"
    cat "$TEMP_DIR/package_dump.json" | head -10 | tee -a "$VALIDATION_LOG"
    failed_tests=$((failed_tests + 1))
fi

# Test 4: Check for unhandled files
log_step "Checking for unhandled files..."
total_tests=$((total_tests + 1))

unhandled_patterns=("*.md" "*.txt" "*.json" "*.sh")
unhandled_found=0

for pattern in "${unhandled_patterns[@]}"; do
    if find Sources Tests -name "$pattern" 2>/dev/null | head -5; then
        unhandled_found=$((unhandled_found + 1))
    fi
done

if [ "$unhandled_found" -eq 0 ]; then
    log_success "No unhandled files found"
    passed_tests=$((passed_tests + 1))
else
    log_warning "$unhandled_found unhandled file types found (will cause build warnings)"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Test 5: Swift Package Build
log_step "Testing Swift Package build..."
total_tests=$((total_tests + 1))

if swift build > "$TEMP_DIR/swift_build.log" 2>&1; then
    log_success "Swift Package build: Successful"
    passed_tests=$((passed_tests + 1))
else
    log_error "Swift Package build: Failed"
    echo "Build errors:" | tee -a "$VALIDATION_LOG"
    tail -20 "$TEMP_DIR/swift_build.log" | tee -a "$VALIDATION_LOG"
    failed_tests=$((failed_tests + 1))
fi

# Test 6: Swift Package Tests
log_step "Running Swift Package tests..."
total_tests=$((total_tests + 1))

if swift test > "$TEMP_DIR/swift_test.log" 2>&1; then
    test_count=$(grep -o "Executed [0-9]* tests" "$TEMP_DIR/swift_test.log" | tail -1 | grep -o "[0-9]*" | head -1 || echo "0")
    log_success "Swift Package tests: $test_count tests passed"
    passed_tests=$((passed_tests + 1))
else
    log_error "Swift Package tests: Failed"
    echo "Test failures:" | tee -a "$VALIDATION_LOG"
    grep -A5 -B5 "failed\|error\|FAIL" "$TEMP_DIR/swift_test.log" | tail -20 | tee -a "$VALIDATION_LOG"
    failed_tests=$((failed_tests + 1))
fi

# Test 7: Check for Print Statements (SwiftLint Custom Rule)
log_step "Checking for print statements..."
total_tests=$((total_tests + 1))

print_violations=$(find Sources Tests -name "*.swift" -exec grep -l "print(" {} \; 2>/dev/null | wc -l)
if [ "$print_violations" -eq 0 ]; then
    log_success "Print statements: None found"
    passed_tests=$((passed_tests + 1))
else
    log_warning "Print statements: $print_violations files contain print() calls"
    find Sources Tests -name "*.swift" -exec grep -l "print(" {} \; 2>/dev/null | head -5 | tee -a "$VALIDATION_LOG"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Test 8: Dependency Resolution
log_step "Testing dependency resolution..."
total_tests=$((total_tests + 1))

if swift package resolve > "$TEMP_DIR/resolve.log" 2>&1; then
    log_success "Dependencies: Resolved successfully"
    passed_tests=$((passed_tests + 1))
else
    log_error "Dependencies: Resolution failed"
    tail -10 "$TEMP_DIR/resolve.log" | tee -a "$VALIDATION_LOG"
    failed_tests=$((failed_tests + 1))
fi

# Test 9: Check for deprecated API usage
log_step "Scanning for deprecated APIs..."
total_tests=$((total_tests + 1))

deprecated_patterns=("unarchiveTopLevelObjectWithData" "archivedData(withRootObject")
deprecated_found=0

for pattern in "${deprecated_patterns[@]}"; do
    if find Sources -name "*.swift" -exec grep -l "$pattern" {} \; 2>/dev/null | head -5; then
        deprecated_found=$((deprecated_found + 1))
    fi
done

if [ "$deprecated_found" -eq 0 ]; then
    log_success "Deprecated APIs: None found"
    passed_tests=$((passed_tests + 1))
else
    log_warning "Deprecated APIs: $deprecated_found found (will cause warnings)"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Test 10: Check Git Status
log_step "Checking git status..."
total_tests=$((total_tests + 1))

if git diff --cached --quiet; then
    log_warning "No staged changes found"
    warnings=$((warnings + 1))
else
    staged_files=$(git diff --cached --name-only | wc -l)
    log_success "Git status: $staged_files files staged for commit"
    
    # Show what files are being committed
    echo "Staged files:" | tee -a "$VALIDATION_LOG"
    git diff --cached --name-only | head -10 | sed 's/^/  /' | tee -a "$VALIDATION_LOG"
fi
passed_tests=$((passed_tests + 1))

# Calculate success rate
success_rate=$(echo "scale=1; ($passed_tests - $warnings) / $total_tests * 100" | bc 2>/dev/null || echo "0")

# Print final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                           Validation Summary                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_info "Pre-Commit Validation Results:"
echo "  Total Tests: $total_tests"
echo "  Passed: $passed_tests"
echo "  Failed: $failed_tests"
echo "  Warnings: $warnings"
echo "  Success Rate: ${success_rate}%"
echo ""

if [ "$failed_tests" -eq 0 ]; then
    log_success "🎉 All validation tests passed! Ready to push to GitHub."
    echo ""
    echo "✅ Swift compatibility verified"
    echo "✅ Package.swift syntax valid"
    echo "✅ Build successful"
    echo "✅ Tests passing"
    echo "✅ Dependencies resolved"
    echo "✅ No incompatible syntax"
    echo ""
    log_info "You can safely push your changes:"
    echo "  git push origin <branch-name>"
    exit_code=0
else
    log_error "❌ $failed_tests validation tests failed"
    echo ""
    log_warning "Please fix the following issues before pushing:"
    echo "  • Remove @preconcurrency syntax (not compatible with Swift 5.10)"
    echo "  • Fix build errors in the validation log"
    echo "  • Resolve dependency conflicts"
    echo "  • Check Swift version compatibility"
    echo ""
    log_info "Fix issues and run this script again before pushing."
    exit_code=1
fi

if [ "$warnings" -gt 0 ]; then
    echo ""
    log_warning "Note: $warnings warnings detected. Consider addressing them for better code quality."
fi

echo ""
log_info "Detailed validation log: $VALIDATION_LOG"
echo ""

exit $exit_code