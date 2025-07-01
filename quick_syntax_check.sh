#!/bin/bash

# Quick Syntax Check for PadTrack
# Lightweight validation that doesn't require Swift CLI

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔍 Quick Syntax Check for PadTrack${NC}"
echo "========================================"

# Check 1: Swift 6.0 incompatible syntax
echo -e "\n${BLUE}[1/4]${NC} Checking for Swift 6.0 incompatible syntax..."
incompatible_found=0

preconcurrency_files=$(find Sources Tests -name "*.swift" -exec grep -l "@preconcurrency" {} \; 2>/dev/null)
if [ -n "$preconcurrency_files" ]; then
    echo -e "${RED}❌ Found @preconcurrency syntax${NC}"
    echo "$preconcurrency_files" | head -5
    incompatible_found=1
fi

consuming_files=$(find Sources Tests -name "*.swift" -exec grep -l "consuming " {} \; 2>/dev/null)
if [ -n "$consuming_files" ]; then
    echo -e "${RED}❌ Found consuming parameters${NC}"
    echo "$consuming_files" | head -5
    incompatible_found=1
fi

borrowing_files=$(find Sources Tests -name "*.swift" -exec grep -l "borrowing " {} \; 2>/dev/null)
if [ -n "$borrowing_files" ]; then
    echo -e "${RED}❌ Found borrowing parameters${NC}"
    echo "$borrowing_files" | head -5
    incompatible_found=1
fi

if [ "$incompatible_found" -eq 0 ]; then
    echo -e "${GREEN}✅ No Swift 6.0 incompatible syntax found${NC}"
fi

# Check 2: Package.swift swift-tools-version
echo -e "\n${BLUE}[2/4]${NC} Checking Package.swift swift-tools-version..."
package_version=$(grep "swift-tools-version:" Package.swift | grep -o '[0-9]\+\.[0-9]\+' || echo "unknown")

if [ "$package_version" = "5.10" ]; then
    echo -e "${GREEN}✅ Package.swift uses Swift 5.10 (CI compatible)${NC}"
elif [ "$package_version" = "unknown" ]; then
    echo -e "${RED}❌ Could not determine swift-tools-version${NC}"
else
    echo -e "${YELLOW}⚠️  Package.swift uses Swift $package_version (CI uses 5.10)${NC}"
fi

# Check 3: Unhandled files check
echo -e "\n${BLUE}[3/4]${NC} Checking for unhandled files..."
unhandled_count=0

# Check if files exist that might cause warnings
if find Sources Tests -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.sh" 2>/dev/null | head -10; then
    unhandled_count=$(find Sources Tests -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.sh" 2>/dev/null | wc -l)
    echo -e "${YELLOW}⚠️  Found $unhandled_count unhandled files (may cause build warnings)${NC}"
else
    echo -e "${GREEN}✅ No unhandled files found${NC}"
fi

# Check 4: Print statements
echo -e "\n${BLUE}[4/4]${NC} Checking for print statements..."
print_count=$(find Sources Tests -name "*.swift" -exec grep -l "print(" {} \; 2>/dev/null | wc -l)

if [ "$print_count" -eq 0 ]; then
    echo -e "${GREEN}✅ No print statements found${NC}"
else
    echo -e "${YELLOW}⚠️  Found print statements in $print_count files${NC}"
fi

echo ""
echo "========================================"

# Summary
if [ "$incompatible_found" -eq 0 ] && [ "$package_version" = "5.10" ]; then
    echo -e "${GREEN}🎉 Quick syntax check passed!${NC}"
    echo -e "${GREEN}✅ Ready for CI pipeline${NC}"
    echo ""
    echo "For complete validation (build + tests), run:"
    echo "  ./pre_commit_validation.sh"
    exit_code=0
else
    echo -e "${RED}❌ Issues found that will cause CI failures${NC}"
    echo ""
    echo "Fix the following:"
    if [ "$incompatible_found" -ne 0 ]; then
        echo "  • Remove @preconcurrency, consuming, borrowing syntax"
    fi
    if [ "$package_version" != "5.10" ]; then
        echo "  • Set swift-tools-version to 5.10 in Package.swift"
    fi
    echo ""
    echo "Then run full validation:"
    echo "  ./pre_commit_validation.sh"
    exit_code=1
fi

if [ "$unhandled_count" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: $unhandled_count unhandled files will cause build warnings${NC}"
    echo "Consider adding exclude clauses to Package.swift"
fi

if [ "$print_count" -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}Note: $print_count files contain print statements${NC}"
    echo "Consider replacing with proper logging"
fi

exit $exit_code