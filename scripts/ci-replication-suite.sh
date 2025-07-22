#!/bin/bash

# CI Replication Suite
# Comprehensive script to replicate various CI environments locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}🔄 CI Replication Suite${NC}"
echo "======================="

# Configuration
PROJECT_NAME="DigitonePad"
SCHEME_NAME="DigitonePad"
PLATFORMS=("iOS Simulator" "iOS Device")
CONFIGURATIONS=("Debug" "Release")
SIMULATORS=("iPad Pro (12.9-inch) (6th generation)" "iPhone 15 Pro")

log() {
    echo -e "$1" | tee -a ci_replication.log
}

# Function to check prerequisites
check_prerequisites() {
    log "${YELLOW}🔍 Checking prerequisites...${NC}"
    
    local missing_tools=()
    
    # Check required tools
    if ! command -v xcodebuild &> /dev/null; then
        missing_tools+=("xcodebuild")
    fi
    
    if ! command -v xcodegen &> /dev/null; then
        missing_tools+=("xcodegen")
    fi
    
    if ! command -v swift &> /dev/null; then
        missing_tools+=("swift")
    fi
    
    if ! command -v xcrun &> /dev/null; then
        missing_tools+=("xcrun")
    fi
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log "${RED}❌ Missing required tools: ${missing_tools[*]}${NC}"
        log "${YELLOW}Please install missing tools before running this script${NC}"
        exit 1
    fi
    
    log "${GREEN}✅ All prerequisites satisfied${NC}"
}

# Function to setup clean environment
setup_clean_environment() {
    log "${YELLOW}🧹 Setting up clean environment...${NC}"
    
    # Create timestamp for this run
    TIMESTAMP=$(date +%Y%m%d_%H%M%S)
    CI_WORK_DIR="/tmp/ci_replication_$TIMESTAMP"
    mkdir -p "$CI_WORK_DIR"
    
    log "${BLUE}📂 CI work directory: $CI_WORK_DIR${NC}"
    
    # Copy project to clean directory
    log "  Copying project to clean directory..."
    cp -R . "$CI_WORK_DIR/"
    
    # Clean up the copy
    cd "$CI_WORK_DIR"
    
    # Remove derived data and build artifacts
    rm -rf .build
    rm -rf "${PROJECT_NAME}.xcodeproj"
    rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*
    
    log "${GREEN}✅ Clean environment ready${NC}"
}

# Function to simulate different CI environments
simulate_github_actions() {
    log "${YELLOW}🐙 Simulating GitHub Actions environment...${NC}"
    
    # Set environment variables similar to GitHub Actions
    export CI=true
    export GITHUB_ACTIONS=true
    export RUNNER_OS=macOS
    export RUNNER_ARCH=X64
    
    # Simulate GitHub Actions workflow
    log "  Setting up GitHub Actions environment variables..."
    
    # Run the build process
    local build_success=true
    
    # Generate project
    if ! xcodegen generate --spec project.yml; then
        log "${RED}❌ GitHub Actions: Project generation failed${NC}"
        build_success=false
    fi
    
    # Resolve dependencies
    if ! swift package resolve; then
        log "${RED}❌ GitHub Actions: Package resolution failed${NC}"
        build_success=false
    fi
    
    # Build and test
    if ! xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' -configuration Debug clean build test; then
        log "${RED}❌ GitHub Actions: Build/test failed${NC}"
        build_success=false
    fi
    
    if [[ "$build_success" == true ]]; then
        log "${GREEN}✅ GitHub Actions simulation: SUCCESS${NC}"
    else
        log "${RED}❌ GitHub Actions simulation: FAILED${NC}"
    fi
    
    # Clean up environment variables
    unset CI GITHUB_ACTIONS RUNNER_OS RUNNER_ARCH
    
    return $([[ "$build_success" == true ]] && echo 0 || echo 1)
}

# Function to simulate Xcode Cloud
simulate_xcode_cloud() {
    log "${YELLOW}☁️ Simulating Xcode Cloud environment...${NC}"
    
    # Set environment variables similar to Xcode Cloud
    export CI_XCODE_CLOUD=true
    export CI_WORKSPACE="$(pwd)"
    export CI_PRIMARY_REPOSITORY_PATH="$(pwd)"
    export CI_BRANCH="main"
    export CI_COMMIT="$(git rev-parse HEAD 2>/dev/null || echo 'unknown')"
    export CI_XCODE_VERSION="15.4"
    
    # Run pre-build script if it exists
    if [[ -f "ci_scripts/ci_pre_xcodebuild.sh" ]]; then
        log "  Running Xcode Cloud pre-build script..."
        chmod +x ci_scripts/ci_pre_xcodebuild.sh
        if ! ./ci_scripts/ci_pre_xcodebuild.sh; then
            log "${RED}❌ Xcode Cloud: Pre-build script failed${NC}"
            return 1
        fi
    fi
    
    local build_success=true
    
    # Build for iOS
    if ! xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'generic/platform=iOS Simulator' -configuration Release clean build; then
        log "${RED}❌ Xcode Cloud: iOS build failed${NC}"
        build_success=false
    fi
    
    # Run post-build script if it exists
    if [[ -f "ci_scripts/ci_post_xcodebuild.sh" ]]; then
        log "  Running Xcode Cloud post-build script..."
        chmod +x ci_scripts/ci_post_xcodebuild.sh
        if ! ./ci_scripts/ci_post_xcodebuild.sh; then
            log "${RED}❌ Xcode Cloud: Post-build script failed${NC}"
            build_success=false
        fi
    fi
    
    if [[ "$build_success" == true ]]; then
        log "${GREEN}✅ Xcode Cloud simulation: SUCCESS${NC}"
    else
        log "${RED}❌ Xcode Cloud simulation: FAILED${NC}"
    fi
    
    # Clean up environment variables
    unset CI_XCODE_CLOUD CI_WORKSPACE CI_PRIMARY_REPOSITORY_PATH CI_BRANCH CI_COMMIT CI_XCODE_VERSION
    
    return $([[ "$build_success" == true ]] && echo 0 || echo 1)
}

# Function to simulate fresh machine build
simulate_fresh_machine() {
    log "${YELLOW}🖥️ Simulating fresh machine build...${NC}"
    
    # Clear all possible caches
    log "  Clearing all possible caches..."
    
    # Clear Xcode caches
    rm -rf ~/Library/Developer/Xcode/DerivedData
    rm -rf ~/Library/Caches/com.apple.dt.Xcode
    
    # Clear Swift package caches
    rm -rf ~/Library/Caches/org.swift.swiftpm
    
    # Clear simulator caches
    xcrun simctl erase all
    
    # Clear any project-specific caches
    rm -rf .build
    rm -rf "${PROJECT_NAME}.xcodeproj"
    
    local build_success=true
    
    # Generate project from scratch
    if ! xcodegen generate --spec project.yml; then
        log "${RED}❌ Fresh machine: Project generation failed${NC}"
        build_success=false
    fi
    
    # Resolve all dependencies fresh
    if ! swift package resolve; then
        log "${RED}❌ Fresh machine: Package resolution failed${NC}"
        build_success=false
    fi
    
    # Build from scratch
    if ! xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' -configuration Debug clean build; then
        log "${RED}❌ Fresh machine: Build failed${NC}"
        build_success=false
    fi
    
    if [[ "$build_success" == true ]]; then
        log "${GREEN}✅ Fresh machine simulation: SUCCESS${NC}"
    else
        log "${RED}❌ Fresh machine simulation: FAILED${NC}"
    fi
    
    return $([[ "$build_success" == true ]] && echo 0 || echo 1)
}

# Function to test different Xcode versions
test_xcode_versions() {
    log "${YELLOW}🔧 Testing different Xcode version compatibility...${NC}"
    
    # Get current Xcode version
    local current_xcode=$(xcodebuild -version | head -1 | cut -d' ' -f2)
    log "  Current Xcode version: $current_xcode"
    
    # Test with different iOS deployment targets
    local deployment_targets=("16.0" "17.0" "18.0")
    
    for target in "${deployment_targets[@]}"; do
        log "  Testing with iOS deployment target: $target"
        
        # Temporarily modify project.yml
        if [[ -f "project.yml" ]]; then
            sed -i.bak "s/iOS: \"16\.0\"/iOS: \"$target\"/" project.yml
            
            # Regenerate project
            if xcodegen generate --spec project.yml; then
                # Try to build
                if xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' -configuration Debug build > /dev/null 2>&1; then
                    log "${GREEN}✅ iOS $target: Compatible${NC}"
                else
                    log "${RED}❌ iOS $target: Build failed${NC}"
                fi
            else
                log "${RED}❌ iOS $target: Project generation failed${NC}"
            fi
            
            # Restore original
            mv project.yml.bak project.yml
        fi
    done
}

# Function to test different configurations
test_configurations() {
    log "${YELLOW}⚙️ Testing different build configurations...${NC}"
    
    for config in "${CONFIGURATIONS[@]}"; do
        log "  Testing $config configuration..."
        
        if xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' -configuration "$config" clean build > /dev/null 2>&1; then
            log "${GREEN}✅ $config: Build successful${NC}"
        else
            log "${RED}❌ $config: Build failed${NC}"
        fi
    done
}

# Function to test different simulators
test_simulators() {
    log "${YELLOW}📱 Testing different simulators...${NC}"
    
    for simulator in "${SIMULATORS[@]}"; do
        log "  Testing on $simulator..."
        
        if xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination "platform=iOS Simulator,name=$simulator,OS=latest" -configuration Debug build > /dev/null 2>&1; then
            log "${GREEN}✅ $simulator: Build successful${NC}"
        else
            log "${RED}❌ $simulator: Build failed${NC}"
        fi
    done
}

# Function to generate comprehensive report
generate_report() {
    log "${YELLOW}📊 Generating comprehensive CI replication report...${NC}"
    
    local report_file="CI_REPLICATION_REPORT_$(date +%Y%m%d_%H%M%S).md"
    
    cat > "$report_file" << EOF
# CI Replication Report

**Date:** $(date)
**Project:** $PROJECT_NAME
**Xcode Version:** $(xcodebuild -version | head -1)
**Swift Version:** $(swift --version | head -1)

## Summary

This report contains the results of comprehensive CI environment replication testing.

## Environment Test Results

### GitHub Actions Simulation
$(if simulate_github_actions; then echo "✅ **PASSED**"; else echo "❌ **FAILED**"; fi)

### Xcode Cloud Simulation
$(if simulate_xcode_cloud; then echo "✅ **PASSED**"; else echo "❌ **FAILED**"; fi)

### Fresh Machine Simulation
$(if simulate_fresh_machine; then echo "✅ **PASSED**"; else echo "❌ **FAILED**"; fi)

## Build Configuration Results

$(for config in "${CONFIGURATIONS[@]}"; do
    if xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' -configuration "$config" clean build > /dev/null 2>&1; then
        echo "- ✅ $config: Success"
    else
        echo "- ❌ $config: Failed"
    fi
done)

## Simulator Test Results

$(for simulator in "${SIMULATORS[@]}"; do
    if xcodebuild -project "${PROJECT_NAME}.xcodeproj" -scheme "${SCHEME_NAME}" -destination "platform=iOS Simulator,name=$simulator,OS=latest" -configuration Debug build > /dev/null 2>&1; then
        echo "- ✅ $simulator: Success"
    else
        echo "- ❌ $simulator: Failed"
    fi
done)

## Recommendations

1. **Fix any failing configurations** before pushing to CI
2. **Test on multiple simulators** to ensure compatibility
3. **Run this script regularly** to catch issues early
4. **Update CI scripts** based on local testing results

## Files Generated

- Full log: ci_replication.log
- Work directory: $CI_WORK_DIR

## Next Steps

1. Address any failing tests
2. Update CI configuration if needed
3. Run this script after major changes
4. Consider adding to pre-commit hooks

EOF

    log "${GREEN}✅ Report generated: $report_file${NC}"
    
    # Copy report to original directory
    cp "$report_file" "$OLDPWD/"
}

# Main execution
main() {
    local original_dir=$(pwd)
    
    # Change to script directory
    cd "$(dirname "${BASH_SOURCE[0]}")/.."
    
    # Initialize log
    echo "CI Replication Suite started at $(date)" > ci_replication.log
    
    # Run all tests
    check_prerequisites
    setup_clean_environment
    
    # Run simulations
    simulate_github_actions
    simulate_xcode_cloud
    simulate_fresh_machine
    
    # Run compatibility tests
    test_xcode_versions
    test_configurations
    test_simulators
    
    # Generate report
    generate_report
    
    # Return to original directory
    cd "$original_dir"
    
    log "${GREEN}🎉 CI Replication Suite completed${NC}"
    log "${BLUE}📄 Check the generated report for detailed results${NC}"
}

# Run if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi