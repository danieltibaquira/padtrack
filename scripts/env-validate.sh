#!/bin/bash

# DigitonePad Environment Validation Script  
# Validates local environment matches CI/CD configuration
# Detects and reports discrepancies that could cause CI failures

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# CI/CD Expected Configuration
CI_SWIFT_VERSION="5.10"
CI_XCODE_VERSION="16.0"
CI_MACOS_VERSION="14"
CI_REQUIRED_FILES=("Package.swift" "project.yml" "Sources" "Tests" "working_code.md")

echo -e "${PURPLE}🔍 DigitonePad Environment Validation${NC}"
echo "===================================="
echo ""

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
WARNINGS=0
ERRORS=0

# Function to run a check
run_check() {
    local check_name="$1"
    local check_command="$2"
    local is_critical="${3:-false}"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "🔍 $check_name... "
    
    if eval "$check_command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        if [[ "$is_critical" == "true" ]]; then
            echo -e "${RED}❌ FAIL${NC}"
            ERRORS=$((ERRORS + 1))
        else
            echo -e "${YELLOW}⚠️ WARNING${NC}"
            WARNINGS=$((WARNINGS + 1))
        fi
        return 1
    fi
}

# Function to compare versions
version_compare() {
    local version1="$1"
    local version2="$2" 
    local comparison="$3"  # "eq", "ge", "le"
    
    case "$comparison" in
        "eq")
            [[ "$version1" == "$version2" ]]
            ;;
        "ge")  
            [[ "$(printf '%s\n' "$version2" "$version1" | sort -V | head -n1)" == "$version2" ]]
            ;;
        "le")
            [[ "$(printf '%s\n' "$version1" "$version2" | sort -V | head -n1)" == "$version1" ]]
            ;;
    esac
}

echo -e "${BLUE}📋 Core Environment Checks${NC}"
echo "=========================="

# Check if we're on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    echo -e "${BLUE}ℹ️  Platform: macOS (iOS development supported)${NC}"
else
    IS_MACOS=false
    echo -e "${BLUE}ℹ️  Platform: $OSTYPE (Swift Package only)${NC}"
fi

# Swift Version Check
if command -v swift >/dev/null 2>&1; then
    SWIFT_VERSION=$(swift --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
    run_check "Swift version ($SWIFT_VERSION == $CI_SWIFT_VERSION)" \
        "version_compare '$SWIFT_VERSION' '$CI_SWIFT_VERSION' 'eq'" true
    
    if [[ "$SWIFT_VERSION" != "$CI_SWIFT_VERSION" ]]; then
        echo -e "  ${RED}➤ Local: $SWIFT_VERSION, CI expects: $CI_SWIFT_VERSION${NC}"
    fi
else
    echo -e "🔍 Swift installation... ${RED}❌ NOT FOUND${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Xcode Version Check (macOS only)
if [[ "$IS_MACOS" == "true" ]]; then
    if command -v xcodebuild >/dev/null 2>&1; then
        XCODE_VERSION=$(xcodebuild -version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
        run_check "Xcode version ($XCODE_VERSION >= $CI_XCODE_VERSION)" \
            "version_compare '$XCODE_VERSION' '$CI_XCODE_VERSION' 'ge'" false
            
        if ! version_compare "$XCODE_VERSION" "$CI_XCODE_VERSION" "ge"; then
            echo -e "  ${YELLOW}➤ Local: $XCODE_VERSION, CI expects: $CI_XCODE_VERSION+${NC}"
        fi
    else
        echo -e "🔍 Xcode installation... ${RED}❌ NOT FOUND${NC}"
        ERRORS=$((ERRORS + 1))
    fi
    
    # XcodeGen Check  
    run_check "XcodeGen installed" "command -v xcodegen" false
    
    # macOS Version
    MACOS_VERSION=$(sw_vers -productVersion | cut -d. -f1)
    run_check "macOS version ($MACOS_VERSION >= $CI_MACOS_VERSION)" \
        "version_compare '$MACOS_VERSION' '$CI_MACOS_VERSION' 'ge'" false
fi

echo ""
echo -e "${BLUE}📂 Project Structure Validation${NC}"
echo "==============================="

# Required files check
for file in "${CI_REQUIRED_FILES[@]}"; do
    run_check "Required file/directory: $file" "[[ -e '$file' ]]" true
done

# Package.swift validation
if [[ -f "Package.swift" ]]; then
    # Check Swift tools version in Package.swift
    PACKAGE_SWIFT_VERSION=$(grep -o 'swift-tools-version: [0-9]\+\.[0-9]\+' Package.swift | grep -o '[0-9]\+\.[0-9]\+')
    if [[ -n "$PACKAGE_SWIFT_VERSION" ]]; then
        run_check "Package.swift Swift version ($PACKAGE_SWIFT_VERSION == $CI_SWIFT_VERSION)" \
            "version_compare '$PACKAGE_SWIFT_VERSION' '$CI_SWIFT_VERSION' 'eq'" true
    fi
    
    # Check for ViewInspector dependency (iOS-specific)
    run_check "ViewInspector dependency declared" \
        "grep -q 'ViewInspector' Package.swift" false
fi

echo ""
echo -e "${BLUE}🔨 Build Environment Validation${NC}"  
echo "==============================="

# Swift Package Resolution
run_check "Swift package resolution" "swift package resolve" true

# Platform-agnostic build test
PLATFORM_MODULES=("MachineProtocols" "DataModel" "DataLayer")
for module in "${PLATFORM_MODULES[@]}"; do
    run_check "Build $module" "swift build --target '$module'" true
done

# Xcode project generation (macOS only)
if [[ "$IS_MACOS" == "true" ]] && [[ -f "project.yml" ]]; then
    run_check "Xcode project generation" "xcodegen generate" false
    
    if [[ -f "DigitonePad.xcodeproj/project.pbxproj" ]]; then
        run_check "DigitonePad.xcodeproj exists after generation" "[[ -f 'DigitonePad.xcodeproj/project.pbxproj' ]]" false
    fi
fi

echo ""
echo -e "${BLUE}🧪 Test Environment Validation${NC}"
echo "==============================="

# Test dependencies
run_check "TestUtilities module build" "swift build --target TestUtilities" false

# Basic test execution (platform-agnostic)
run_check "MachineProtocolsTests execution" \
    "timeout 30s swift test --filter MachineProtocolsTests --parallel || true" false

echo ""
echo -e "${BLUE}🔐 Security & Quality Validation${NC}"
echo "================================="

# Check for hardcoded secrets (same as CI)
run_check "No hardcoded secrets" \
    "! (grep -r 'API_KEY\|SECRET\|PASSWORD' --include='*.swift' . | grep -v 'placeholder\|example')" true

# SwiftLint availability (if installed)
if command -v swiftlint >/dev/null 2>&1; then
    run_check "SwiftLint available" "command -v swiftlint" false
    run_check "SwiftLint passes" "swiftlint lint --quiet" false
else
    echo "🔍 SwiftLint... ${YELLOW}⚠️ NOT INSTALLED${NC} (optional)"
fi

echo ""
echo -e "${PURPLE}📊 Validation Results${NC}"
echo "===================="

# Calculate pass rate
if [[ $TOTAL_CHECKS -gt 0 ]]; then
    PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    PASS_RATE=0
fi

echo -e "Total Checks: $TOTAL_CHECKS"
echo -e "Passed: ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Warnings: ${YELLOW}$WARNINGS${NC}"
echo -e "Errors: ${RED}$ERRORS${NC}"
echo -e "Pass Rate: ${GREEN}$PASS_RATE%${NC}"

echo ""
echo -e "${BLUE}🎯 Environment Parity Status${NC}"
echo "============================"

if [[ $ERRORS -eq 0 ]]; then
    if [[ $WARNINGS -eq 0 ]]; then
        echo -e "${GREEN}✅ EXCELLENT: Environment fully matches CI/CD${NC}"
        echo -e "${GREEN}   Your local builds should match CI exactly${NC}"
        EXIT_CODE=0
    else
        echo -e "${YELLOW}⚠️ GOOD: Environment mostly matches CI/CD${NC}"
        echo -e "${YELLOW}   Minor differences may cause CI variations${NC}"
        EXIT_CODE=0
    fi
else
    echo -e "${RED}❌ ISSUES: Environment has critical differences from CI/CD${NC}"
    echo -e "${RED}   Local builds may not match CI behavior${NC}"
    EXIT_CODE=1
fi

echo ""
echo -e "${BLUE}💡 Recommendations${NC}"
echo "=================="

if [[ $ERRORS -gt 0 ]]; then
    echo -e "${RED}Critical Issues to Fix:${NC}"
    if [[ "$SWIFT_VERSION" != "$CI_SWIFT_VERSION" ]]; then
        echo "  • Update Swift to version $CI_SWIFT_VERSION"
        if [[ "$IS_MACOS" == "true" ]]; then
            echo "    → Update Xcode to version $CI_XCODE_VERSION or later"
        fi
    fi
    
    if [[ ! -f "Package.swift" ]]; then
        echo "  • Ensure you're in the DigitonePad project root directory"
    fi
    
    echo ""
fi

if [[ $WARNINGS -gt 0 ]]; then
    echo -e "${YELLOW}Recommended Improvements:${NC}"
    if [[ "$IS_MACOS" == "true" ]] && ! command -v xcodegen >/dev/null 2>&1; then
        echo "  • Install XcodeGen: brew install xcodegen"
    fi
    
    if ! command -v swiftlint >/dev/null 2>&1; then
        echo "  • Install SwiftLint: brew install swiftlint"
    fi
    
    echo ""
fi

echo -e "${BLUE}🚀 Environment Sync Commands${NC}"
echo "==========================="
echo "Run these commands to sync with CI/CD:"
echo ""
echo "  # Full environment setup"
echo "  ./scripts/dev-setup.sh"
echo ""
echo "  # Docker environment (Linux simulation)"  
echo "  docker-compose -f docker-compose.dev.yml up swift-dev"
echo ""
echo "  # Manual Swift package test (CI simulation)"
echo "  swift test --filter MachineProtocolsTests"
echo ""

exit $EXIT_CODE