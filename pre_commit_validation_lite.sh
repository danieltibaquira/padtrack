#!/bin/bash

# Lightweight Pre-Commit Validation for PadTrack
# Works without Swift CLI and focuses on syntax/compatibility checks

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                     PadTrack Lite Pre-Commit Validation                     ║"
echo "║                      Syntax & Compatibility Checks                          ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""

# Initialize counters
total_tests=0
passed_tests=0
failed_tests=0
warnings=0

# Test 1: Package.swift Swift Version
echo -e "${BLUE}[1/6]${NC} Checking Package.swift Swift version..."
total_tests=$((total_tests + 1))

if grep -q "swift-tools-version: 5\." Package.swift; then
    version=$(grep "swift-tools-version:" Package.swift | grep -o '[0-9]\+\.[0-9]\+')
    echo -e "${GREEN}✅ Package.swift uses Swift $version (CI compatible)${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${RED}❌ Package.swift uses unsupported Swift version${NC}"
    failed_tests=$((failed_tests + 1))
fi

# Test 2: Swift 6.0 Incompatible Syntax (Precise)
echo -e "\n${BLUE}[2/6]${NC} Checking for Swift 6.0 incompatible syntax..."
total_tests=$((total_tests + 1))

incompatible_found=0

# Check for @preconcurrency in source files (not validation scripts)
preconcurrency_files=$(find Sources Tests -name "*.swift" -exec grep -l "@preconcurrency" {} \; 2>/dev/null | grep -v validation || true)
if [ -n "$preconcurrency_files" ]; then
    echo -e "${RED}❌ Found @preconcurrency syntax${NC}"
    echo "$preconcurrency_files" | head -3
    incompatible_found=1
fi

# Check for consuming parameters (precise pattern)
consuming_files=$(find Sources Tests -name "*.swift" -exec grep -l "consuming [a-zA-Z]" {} \; 2>/dev/null || true)
if [ -n "$consuming_files" ]; then
    echo -e "${RED}❌ Found consuming parameters${NC}"
    echo "$consuming_files" | head -3
    incompatible_found=1
fi

# Check for borrowing parameters (precise pattern)
borrowing_files=$(find Sources Tests -name "*.swift" -exec grep -l "borrowing [a-zA-Z]" {} \; 2>/dev/null || true)
if [ -n "$borrowing_files" ]; then
    echo -e "${RED}❌ Found borrowing parameters${NC}"
    echo "$borrowing_files" | head -3
    incompatible_found=1
fi

if [ "$incompatible_found" -eq 0 ]; then
    echo -e "${GREEN}✅ No Swift 6.0 incompatible syntax found${NC}"
    passed_tests=$((passed_tests + 1))
else
    failed_tests=$((failed_tests + 1))
fi

# Test 3: Package.swift Language Modes
echo -e "\n${BLUE}[3/6]${NC} Checking Package.swift language modes..."
total_tests=$((total_tests + 1))

if grep -q "swiftLanguageModes" Package.swift; then
    echo -e "${RED}❌ Package.swift contains swiftLanguageModes (Swift 6.0 feature)${NC}"
    failed_tests=$((failed_tests + 1))
else
    echo -e "${GREEN}✅ No Swift 6.0 language modes found${NC}"
    passed_tests=$((passed_tests + 1))
fi

# Test 4: Unhandled Files Check
echo -e "\n${BLUE}[4/6]${NC} Checking for unhandled files..."
total_tests=$((total_tests + 1))

unhandled_count=0
for dir in Sources Tests; do
    if [ -d "$dir" ]; then
        unhandled=$(find "$dir" -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.sh" | wc -l)
        unhandled_count=$((unhandled_count + unhandled))
    fi
done

if [ "$unhandled_count" -eq 0 ]; then
    echo -e "${GREEN}✅ No unhandled files found${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${YELLOW}⚠️  Found $unhandled_count unhandled files (may cause build warnings)${NC}"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Test 5: Print Statements (SwiftLint Rule)
echo -e "\n${BLUE}[5/6]${NC} Checking for print statements..."
total_tests=$((total_tests + 1))

print_count=$(find Sources Tests -name "*.swift" -exec grep -l "print(" {} \; 2>/dev/null | wc -l)
if [ "$print_count" -eq 0 ]; then
    echo -e "${GREEN}✅ No print statements found${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${YELLOW}⚠️  Found print statements in $print_count files${NC}"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Test 6: Deprecated APIs
echo -e "\n${BLUE}[6/6]${NC} Checking for deprecated APIs..."
total_tests=$((total_tests + 1))

deprecated_count=0
if find Sources -name "*.swift" -exec grep -l "unarchiveTopLevelObjectWithData" {} \; 2>/dev/null | head -1 > /dev/null; then
    deprecated_count=$((deprecated_count + 1))
fi
if find Sources -name "*.swift" -exec grep -l "archivedData(withRootObject" {} \; 2>/dev/null | head -1 > /dev/null; then
    deprecated_count=$((deprecated_count + 1))
fi

if [ "$deprecated_count" -eq 0 ]; then
    echo -e "${GREEN}✅ No deprecated APIs found${NC}"
    passed_tests=$((passed_tests + 1))
else
    echo -e "${YELLOW}⚠️  Found $deprecated_count deprecated API patterns${NC}"
    warnings=$((warnings + 1))
    passed_tests=$((passed_tests + 1))
fi

# Calculate results
actual_failures=$((failed_tests))
success_rate=$(echo "scale=0; ($passed_tests - $warnings) * 100 / $total_tests" | bc 2>/dev/null || echo "0")

# Summary
echo ""
echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║                              Validation Summary                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo ""
echo -e "${BLUE}Results:${NC}"
echo "  Total Tests: $total_tests"
echo "  Passed: $passed_tests"
echo "  Failed: $failed_tests"
echo "  Warnings: $warnings"
echo "  Success Rate: ${success_rate}%"
echo ""

if [ "$actual_failures" -eq 0 ]; then
    echo -e "${GREEN}🎉 Lite validation passed!${NC}"
    echo -e "${GREEN}✅ Ready for CI pipeline${NC}"
    echo ""
    if [ "$warnings" -gt 0 ]; then
        echo -e "${YELLOW}Note: $warnings warnings detected${NC}"
        echo "Consider addressing them for better code quality"
        echo ""
    fi
    echo "For complete validation with build + tests:"
    echo "  ./pre_commit_validation.sh"
    exit 0
else
    echo -e "${RED}❌ $actual_failures critical issues found${NC}"
    echo ""
    echo "Please fix the following before pushing:"
    echo "  • Update Package.swift to use Swift 5.10"
    echo "  • Remove Swift 6.0 specific syntax"
    echo "  • Add exclude clauses for unhandled files"
    echo ""
    exit 1
fi