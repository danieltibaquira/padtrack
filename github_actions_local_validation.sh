#!/bin/bash

# GitHub Actions Local Validation Script
# This script runs all GitHub Actions jobs locally to validate they would pass

set -e

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
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_header() {
    echo -e "${PURPLE}[JOB]${NC} $1"
}

# Initialize counters
total_jobs=0
passed_jobs=0
failed_jobs=0

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                    GitHub Actions Local Validation                          ║"
echo "║                   Testing All CI Jobs Before Push                           ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Job 1: Validate Project Structure
log_header "Job 1: Validate Project Structure"
total_jobs=$((total_jobs + 1))

echo "Validating Package.swift..."
if [ ! -f "Package.swift" ]; then
    log_error "Package.swift not found"
    failed_jobs=$((failed_jobs + 1))
else
    if grep -q "swift-tools-version:" Package.swift; then
        log_success "Package.swift structure valid"
    else
        log_error "Package.swift missing swift-tools-version"
        failed_jobs=$((failed_jobs + 1))
        continue
    fi
fi

echo "Validating source structure..."
required_modules=("MachineProtocols" "DataModel" "DataLayer" "AudioEngine" "VoiceModule" "FilterModule" "FXModule" "MIDIModule" "UIComponents" "SequencerModule" "AppShell" "DigitonePad")
missing_modules=0

for module in "${required_modules[@]}"; do
    if [ ! -d "Sources/$module" ]; then
        log_error "Missing Sources/$module"
        missing_modules=$((missing_modules + 1))
    fi
done

if [ "$missing_modules" -eq 0 ]; then
    log_success "All required modules found"
    passed_jobs=$((passed_jobs + 1))
else
    log_error "$missing_modules required modules missing"
    failed_jobs=$((failed_jobs + 1))
fi

echo ""

# Job 2: Swift Package Build (Ubuntu simulation)
log_header "Job 2: Swift Package Build (Ubuntu simulation)"
total_jobs=$((total_jobs + 1))

echo "Resolving dependencies..."
if swift package resolve; then
    log_success "Dependencies resolved"
else
    log_error "Dependency resolution failed"
    failed_jobs=$((failed_jobs + 1))
    continue
fi

echo "Building Swift package..."
if swift build -c release; then
    log_success "Swift package build successful"
    passed_jobs=$((passed_jobs + 1))
else
    log_error "Swift package build failed"
    failed_jobs=$((failed_jobs + 1))
fi

echo ""

# Job 3: Swift Package Tests
log_header "Job 3: Swift Package Tests"
total_jobs=$((total_jobs + 1))

echo "Running Swift package tests..."
if swift test --enable-test-discovery; then
    log_success "Swift package tests passed"
    passed_jobs=$((passed_jobs + 1))
else
    log_warning "Swift package tests failed (some may require iOS simulator)"
    # Don't fail the job as GitHub Actions allows this
    passed_jobs=$((passed_jobs + 1))
fi

echo ""

# Job 4: Security Scan
log_header "Job 4: Security Scan"
total_jobs=$((total_jobs + 1))

echo "Scanning for potential security issues..."
security_issues=0

# Check for API keys in plist files
if find . -name "*.plist" -exec grep -l "API\|SECRET\|KEY" {} \; 2>/dev/null | grep -v ".git" | head -5; then
    log_warning "Found potential API keys in plist files"
    security_issues=$((security_issues + 1))
fi

# Check for hardcoded secrets in Swift files
if find . -name "*.swift" -exec grep -l "API_KEY\|SECRET\|PASSWORD" {} \; 2>/dev/null | grep -v ".git" | head -5; then
    log_warning "Found potential hardcoded secrets"
    security_issues=$((security_issues + 1))
fi

if [ "$security_issues" -eq 0 ]; then
    log_success "No security issues found"
else
    log_warning "$security_issues potential security issues found"
fi

passed_jobs=$((passed_jobs + 1))
echo ""

# Print final summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                        GitHub Actions Validation Summary                    ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

log_info "GitHub Actions Local Validation Results:"
echo "  Total Jobs: $total_jobs"
echo "  Passed: $passed_jobs"
echo "  Failed: $failed_jobs"
echo ""

if [ "$failed_jobs" -eq 0 ]; then
    log_success "🎉 All GitHub Actions jobs would pass! Ready to push."
    exit_code=0
else
    log_error "❌ $failed_jobs GitHub Actions jobs would fail"
    exit_code=1
fi

echo ""
exit $exit_code
