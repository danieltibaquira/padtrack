#!/bin/bash

# DigitonePad Build Validation Script
# Validates project structure and configuration without requiring Swift toolchain

set -e

echo "🔍 DigitonePad Build Validation"
echo "==============================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validation functions
validate_package_swift() {
    echo -e "${BLUE}📦 Validating Package.swift...${NC}"
    
    if [ ! -f "Package.swift" ]; then
        echo -e "${RED}❌ Package.swift not found${NC}"
        return 1
    fi
    
    # Check swift-tools-version
    if ! grep -q "swift-tools-version:" Package.swift; then
        echo -e "${RED}❌ Package.swift missing swift-tools-version${NC}"
        return 1
    fi
    
    # Check for basic structure
    if ! grep -q "Package(" Package.swift; then
        echo -e "${RED}❌ Package.swift missing Package declaration${NC}"
        return 1
    fi
    
    # Check for products
    if ! grep -q "products:" Package.swift; then
        echo -e "${RED}❌ Package.swift missing products section${NC}"
        return 1
    fi
    
    # Check for targets
    if ! grep -q "targets:" Package.swift; then
        echo -e "${RED}❌ Package.swift missing targets section${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Package.swift validation passed${NC}"
    return 0
}

validate_source_structure() {
    echo -e "${BLUE}📁 Validating source directory structure...${NC}"
    
    required_modules=("MachineProtocols" "DataModel" "DataLayer" "AudioEngine" "VoiceModule" "FilterModule" "FilterMachine" "FXModule" "MIDIModule" "UIComponents" "SequencerModule" "AppShell" "DigitonePad")
    
    for module in "${required_modules[@]}"; do
        if [ ! -d "Sources/$module" ]; then
            echo -e "${RED}❌ Required module Sources/$module not found${NC}"
            return 1
        fi
        echo -e "${GREEN}✓${NC} Found Sources/$module"
    done
    
    echo -e "${GREEN}✅ Source structure validation passed${NC}"
    return 0
}

validate_test_structure() {
    echo -e "${BLUE}🧪 Validating test directory structure...${NC}"
    
    if [ ! -d "Tests" ]; then
        echo -e "${RED}❌ Tests directory not found${NC}"
        return 1
    fi
    
    if [ ! -d "Tests/TestUtilities" ]; then
        echo -e "${RED}❌ Tests/TestUtilities directory not found${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Test structure validation passed${NC}"
    return 0
}

count_swift_files() {
    echo -e "${BLUE}📊 Counting Swift files...${NC}"
    
    total_files=$(find . -name "*.swift" | wc -l)
    source_files=$(find Sources -name "*.swift" 2>/dev/null | wc -l || echo "0")
    test_files=$(find Tests -name "*.swift" 2>/dev/null | wc -l || echo "0")
    
    echo -e "${GREEN}📄 Total Swift files: $total_files${NC}"
    echo -e "${GREEN}📄 Source files: $source_files${NC}"
    echo -e "${GREEN}📄 Test files: $test_files${NC}"
}

check_build_tools() {
    echo -e "${BLUE}🛠️  Checking build tools availability...${NC}"
    
    if command -v swift >/dev/null 2>&1; then
        swift_version=$(swift --version | head -1)
        echo -e "${GREEN}✅ Swift: $swift_version${NC}"
    else
        echo -e "${YELLOW}⚠️  Swift toolchain not available${NC}"
    fi
    
    if command -v xcodebuild >/dev/null 2>&1; then
        xcode_version=$(xcodebuild -version | head -1)
        echo -e "${GREEN}✅ Xcode: $xcode_version${NC}"
    else
        echo -e "${YELLOW}⚠️  Xcode not available${NC}"
    fi
    
    if command -v xcodegen >/dev/null 2>&1; then
        xcodegen_version=$(xcodegen --version)
        echo -e "${GREEN}✅ XcodeGen: $xcodegen_version${NC}"
    else
        echo -e "${YELLOW}⚠️  XcodeGen not available${NC}"
    fi
}

check_ci_config() {
    echo -e "${BLUE}⚙️  Checking CI configuration...${NC}"
    
    if [ -f ".github/workflows/ci.yml" ]; then
        echo -e "${GREEN}✅ GitHub Actions CI configuration found${NC}"
    else
        echo -e "${YELLOW}⚠️  GitHub Actions CI configuration not found${NC}"
    fi
    
    if [ -f "project.yml" ]; then
        echo -e "${GREEN}✅ XcodeGen project configuration found${NC}"
    else
        echo -e "${YELLOW}⚠️  XcodeGen project configuration not found${NC}"
    fi
}

suggest_next_steps() {
    echo -e "${BLUE}🚀 Suggested next steps:${NC}"
    
    if ! command -v swift >/dev/null 2>&1; then
        echo -e "${YELLOW}1. Install Swift toolchain for local development${NC}"
        echo -e "   - macOS: Install Xcode or Swift command line tools"
        echo -e "   - Linux: Use Docker with swift:5.10 image"
    fi
    
    if ! command -v xcodegen >/dev/null 2>&1; then
        echo -e "${YELLOW}2. Install XcodeGen: brew install xcodegen${NC}"
    fi
    
    echo -e "${GREEN}3. Run CI pipeline in GitHub Actions for full validation${NC}"
    echo -e "${GREEN}4. Use Docker for consistent build environment:${NC}"
    echo -e "   docker run --rm -v \$(pwd):/workspace -w /workspace swift:5.10 swift build"
}

# Main validation
main() {
    echo ""
    
    # Run validations
    validate_package_swift || exit 1
    echo ""
    
    validate_source_structure || exit 1
    echo ""
    
    validate_test_structure || exit 1
    echo ""
    
    count_swift_files
    echo ""
    
    check_build_tools
    echo ""
    
    check_ci_config
    echo ""
    
    suggest_next_steps
    echo ""
    
    echo -e "${GREEN}🎉 Build validation completed successfully!${NC}"
    echo -e "${BLUE}The project structure is ready for compilation.${NC}"
}

# Run if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi