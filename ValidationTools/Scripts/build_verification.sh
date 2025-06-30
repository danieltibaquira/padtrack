#!/bin/bash

# DigitonePad Build Verification Script
# This script performs comprehensive build validation across all supported iPad models

set -e  # Exit on any error

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VALIDATION_DIR="$PROJECT_ROOT/ValidationTools"
REPORTS_DIR="$VALIDATION_DIR/Reports"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
REPORT_FILE="$REPORTS_DIR/build_verification_$TIMESTAMP.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Create reports directory if it doesn't exist
mkdir -p "$REPORTS_DIR"

# Initialize report JSON
cat > "$REPORT_FILE" << EOF
{
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "project_root": "$PROJECT_ROOT",
  "validation_type": "build_verification",
  "results": {
EOF

# Function to add result to JSON report
add_result() {
    local category="$1"
    local status="$2"
    local message="$3"
    local details="$4"
    
    cat >> "$REPORT_FILE" << EOF
    "$category": {
      "status": "$status",
      "message": "$message",
      "details": "$details",
      "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    },
EOF
}

# Function to finalize JSON report
finalize_report() {
    # Remove trailing comma and close JSON
    sed -i '' '$ s/,$//' "$REPORT_FILE"
    cat >> "$REPORT_FILE" << EOF
  },
  "summary": {
    "total_tests": $total_tests,
    "passed_tests": $passed_tests,
    "failed_tests": $failed_tests,
    "warnings": $warnings
  }
}
EOF
}

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

log_info "Starting DigitonePad Build Verification"
log_info "Project Root: $PROJECT_ROOT"
log_info "Report will be saved to: $REPORT_FILE"

# Change to project directory
cd "$PROJECT_ROOT"

# Test 1: Swift Package Build
log_info "Testing Swift Package build..."
total_tests=$((total_tests + 1))

if swift build > /tmp/swift_build.log 2>&1; then
    log_success "Swift Package build successful"
    add_result "swift_package_build" "passed" "Swift Package compiled successfully" "$(cat /tmp/swift_build.log | tail -5)"
    passed_tests=$((passed_tests + 1))
else
    log_error "Swift Package build failed"
    add_result "swift_package_build" "failed" "Swift Package compilation failed" "$(cat /tmp/swift_build.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 2: Swift Package Tests
log_info "Running Swift Package tests..."
total_tests=$((total_tests + 1))

if swift test > /tmp/swift_test.log 2>&1; then
    test_count=$(grep -o "Executed [0-9]* tests" /tmp/swift_test.log | tail -1 | grep -o "[0-9]*" | head -1)
    log_success "Swift Package tests passed ($test_count tests)"
    add_result "swift_package_tests" "passed" "All Swift Package tests passed" "Executed $test_count tests successfully"
    passed_tests=$((passed_tests + 1))
else
    log_error "Swift Package tests failed"
    add_result "swift_package_tests" "failed" "Swift Package tests failed" "$(cat /tmp/swift_test.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 3: iOS Build for iPad Pro 11-inch
log_info "Testing iOS build for iPad Pro 11-inch..."
total_tests=$((total_tests + 1))

if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (4th generation),OS=17.2' build CODE_SIGNING_ALLOWED=NO > /tmp/ios_build_11.log 2>&1; then
    log_success "iOS build for iPad Pro 11-inch successful"
    add_result "ios_build_ipad_pro_11" "passed" "iOS build successful for iPad Pro 11-inch" "Build completed without errors"
    passed_tests=$((passed_tests + 1))
else
    log_error "iOS build for iPad Pro 11-inch failed"
    add_result "ios_build_ipad_pro_11" "failed" "iOS build failed for iPad Pro 11-inch" "$(cat /tmp/ios_build_11.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 4: iOS Build for iPad Pro 12.9-inch
log_info "Testing iOS build for iPad Pro 12.9-inch..."
total_tests=$((total_tests + 1))

if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=17.2' build CODE_SIGNING_ALLOWED=NO > /tmp/ios_build_129.log 2>&1; then
    log_success "iOS build for iPad Pro 12.9-inch successful"
    add_result "ios_build_ipad_pro_129" "passed" "iOS build successful for iPad Pro 12.9-inch" "Build completed without errors"
    passed_tests=$((passed_tests + 1))
else
    log_error "iOS build for iPad Pro 12.9-inch failed"
    add_result "ios_build_ipad_pro_129" "failed" "iOS build failed for iPad Pro 12.9-inch" "$(cat /tmp/ios_build_129.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 5: iOS Build for iPad Air
log_info "Testing iOS build for iPad Air..."
total_tests=$((total_tests + 1))

if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPad Air (5th generation),OS=17.2' build CODE_SIGNING_ALLOWED=NO > /tmp/ios_build_air.log 2>&1; then
    log_success "iOS build for iPad Air successful"
    add_result "ios_build_ipad_air" "passed" "iOS build successful for iPad Air" "Build completed without errors"
    passed_tests=$((passed_tests + 1))
else
    log_error "iOS build for iPad Air failed"
    add_result "ios_build_ipad_air" "failed" "iOS build failed for iPad Air" "$(cat /tmp/ios_build_air.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 6: iOS Build for iPad mini
log_info "Testing iOS build for iPad mini..."
total_tests=$((total_tests + 1))

if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPad mini (6th generation),OS=17.2' build CODE_SIGNING_ALLOWED=NO > /tmp/ios_build_mini.log 2>&1; then
    log_success "iOS build for iPad mini successful"
    add_result "ios_build_ipad_mini" "passed" "iOS build successful for iPad mini" "Build completed without errors"
    passed_tests=$((passed_tests + 1))
else
    log_error "iOS build for iPad mini failed"
    add_result "ios_build_ipad_mini" "failed" "iOS build failed for iPad mini" "$(cat /tmp/ios_build_mini.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 7: Dependency Resolution
log_info "Testing dependency resolution..."
total_tests=$((total_tests + 1))

if swift package resolve > /tmp/package_resolve.log 2>&1; then
    log_success "Package dependencies resolved successfully"
    add_result "dependency_resolution" "passed" "All package dependencies resolved" "No dependency conflicts detected"
    passed_tests=$((passed_tests + 1))
else
    log_error "Package dependency resolution failed"
    add_result "dependency_resolution" "failed" "Package dependency resolution failed" "$(cat /tmp/package_resolve.log | tail -10)"
    failed_tests=$((failed_tests + 1))
fi

# Test 8: Build Warnings Check
log_info "Checking for build warnings..."
total_tests=$((total_tests + 1))

warning_count=0
for log_file in /tmp/swift_build.log /tmp/ios_build_*.log; do
    if [ -f "$log_file" ]; then
        warnings_in_file=$(grep -c "warning:" "$log_file" 2>/dev/null || echo "0")
        if [ "$warnings_in_file" != "0" ]; then
            warning_count=$((warning_count + warnings_in_file))
        fi
    fi
done

if [ "$warning_count" -eq 0 ]; then
    log_success "No build warnings detected"
    add_result "build_warnings" "passed" "No build warnings found" "Clean build with no warnings"
    passed_tests=$((passed_tests + 1))
elif [ "$warning_count" -lt 5 ]; then
    log_warning "$warning_count build warnings detected"
    add_result "build_warnings" "warning" "$warning_count build warnings detected" "Warnings should be reviewed and addressed"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
else
    log_error "$warning_count build warnings detected (too many)"
    add_result "build_warnings" "failed" "$warning_count build warnings detected" "Excessive warnings indicate potential issues"
    failed_tests=$((failed_tests + 1))
fi

# Finalize report
finalize_report

# Print summary
echo ""
log_info "Build Verification Summary:"
echo "  Total Tests: $total_tests"
echo "  Passed: $passed_tests"
echo "  Failed: $failed_tests"
echo "  Warnings: $warnings"
echo ""

if [ "$failed_tests" -eq 0 ]; then
    log_success "All build verification tests passed!"
    exit_code=0
else
    log_error "$failed_tests tests failed"
    exit_code=1
fi

log_info "Detailed report saved to: $REPORT_FILE"

# Clean up temporary files
rm -f /tmp/swift_build.log /tmp/swift_test.log /tmp/ios_build_*.log /tmp/package_resolve.log

exit $exit_code
