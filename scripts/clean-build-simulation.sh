#!/bin/bash

# Clean Build Simulation Script
# Simulates Xcode Cloud's clean build environment locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Clean Build Simulation - Replicating Xcode Cloud Environment${NC}"
echo "=================================================================="

# Configuration
PROJECT_NAME="DigitonePad"
SCHEME_NAME="DigitonePad"
TEMP_DIR="/tmp/xcode_cloud_simulation_$(date +%Y%m%d_%H%M%S)"
DERIVED_DATA_PATH="$TEMP_DIR/DerivedData"

# Create temporary directory for clean build
mkdir -p "$TEMP_DIR"
mkdir -p "$DERIVED_DATA_PATH"

log() {
    echo -e "$1" | tee -a "$TEMP_DIR/build.log"
}

cleanup() {
    log "${YELLOW}🧹 Cleaning up temporary files...${NC}"
    if [[ -d "$TEMP_DIR" ]]; then
        rm -rf "$TEMP_DIR"
    fi
}

# Trap to cleanup on exit
trap cleanup EXIT

log "${BLUE}📂 Using temporary directory: $TEMP_DIR${NC}"
log "${BLUE}📊 Using derived data path: $DERIVED_DATA_PATH${NC}"

# Step 1: Clear all existing build artifacts
log "${YELLOW}1. Clearing existing build artifacts...${NC}"

# Remove Xcode derived data
if [[ -d ~/Library/Developer/Xcode/DerivedData ]]; then
    log "  Clearing Xcode DerivedData..."
    rm -rf ~/Library/Developer/Xcode/DerivedData/${PROJECT_NAME}-*
fi

# Remove Swift build artifacts
if [[ -d ".build" ]]; then
    log "  Removing Swift Package Manager build artifacts..."
    rm -rf .build
fi

# Remove generated Xcode project
if [[ -d "${PROJECT_NAME}.xcodeproj" ]]; then
    log "  Removing generated Xcode project..."
    rm -rf "${PROJECT_NAME}.xcodeproj"
fi

# Step 2: Regenerate project from scratch (like Xcode Cloud)
log "${YELLOW}2. Regenerating project from scratch...${NC}"

if [[ -f "project.yml" ]]; then
    log "  Generating Xcode project from project.yml..."
    xcodegen generate --spec project.yml
    log "${GREEN}✅ Project regenerated successfully${NC}"
else
    log "${RED}❌ project.yml not found${NC}"
    exit 1
fi

# Step 3: Force Core Data class regeneration
log "${YELLOW}3. Forcing Core Data class regeneration...${NC}"

# Remove any existing Core Data generated files
find . -name "*+CoreDataClass.swift" -delete
find . -name "*+CoreDataProperties.swift" -delete

# Clear any cached Core Data model information
if [[ -d ~/Library/Developer/CoreSimulator ]]; then
    log "  Clearing Core Data simulator cache..."
    find ~/Library/Developer/CoreSimulator -name "*.sqlite*" -delete 2>/dev/null || true
fi

log "${GREEN}✅ Core Data cache cleared${NC}"

# Step 4: Swift Package dependency resolution (clean)
log "${YELLOW}4. Resolving Swift Package dependencies...${NC}"

# Clear package cache
if [[ -d ~/Library/Caches/org.swift.swiftpm ]]; then
    log "  Clearing Swift Package Manager cache..."
    rm -rf ~/Library/Caches/org.swift.swiftpm
fi

# Reset package state
if [[ -f "Package.resolved" ]]; then
    log "  Removing Package.resolved..."
    rm Package.resolved
fi

# Fresh package resolution
log "  Resolving packages from scratch..."
if swift package resolve; then
    log "${GREEN}✅ Package dependencies resolved${NC}"
else
    log "${RED}❌ Package resolution failed${NC}"
    exit 1
fi

# Step 5: Clean build with isolated derived data
log "${YELLOW}5. Performing clean build with isolated derived data...${NC}"

# Build using custom derived data location (isolated from system)
# Get dynamic simulator destination
SIMULATOR_DESTINATION=$(./scripts/get-simulator-destination.sh destination iPad)

BUILD_COMMAND="xcodebuild -project ${PROJECT_NAME}.xcodeproj -scheme ${SCHEME_NAME} -destination '$SIMULATOR_DESTINATION' -derivedDataPath ${DERIVED_DATA_PATH} -configuration Debug clean build"

log "  Executing build command:"
log "  $BUILD_COMMAND"

if $BUILD_COMMAND > "$TEMP_DIR/xcodebuild.log" 2>&1; then
    log "${GREEN}✅ Clean build successful${NC}"
else
    log "${RED}❌ Clean build failed${NC}"
    
    # Extract and display errors
    log "${RED}Build errors:${NC}"
    grep -E "error:|fatal error:|❌" "$TEMP_DIR/xcodebuild.log" | head -20 | while read line; do
        log "  $line"
    done
    
    # Save full build log
    cp "$TEMP_DIR/xcodebuild.log" "./clean_build_errors.log"
    log "${YELLOW}Full build log saved to: ./clean_build_errors.log${NC}"
    
    exit 1
fi

# Step 6: Test build for different configurations
log "${YELLOW}6. Testing Release configuration...${NC}"

RELEASE_BUILD_COMMAND="xcodebuild -project ${PROJECT_NAME}.xcodeproj -scheme ${SCHEME_NAME} -destination '$SIMULATOR_DESTINATION' -derivedDataPath ${DERIVED_DATA_PATH} -configuration Release build"

if $RELEASE_BUILD_COMMAND > "$TEMP_DIR/release_build.log" 2>&1; then
    log "${GREEN}✅ Release build successful${NC}"
else
    log "${RED}❌ Release build failed${NC}"
    
    # Extract and display errors
    log "${RED}Release build errors:${NC}"
    grep -E "error:|fatal error:|❌" "$TEMP_DIR/release_build.log" | head -10 | while read line; do
        log "  $line"
    done
fi

# Step 7: Run tests in clean environment
log "${YELLOW}7. Running tests in clean environment...${NC}"

TEST_COMMAND="xcodebuild -project ${PROJECT_NAME}.xcodeproj -scheme ${SCHEME_NAME} -destination '$SIMULATOR_DESTINATION' -derivedDataPath ${DERIVED_DATA_PATH} -configuration Debug test"

if $TEST_COMMAND > "$TEMP_DIR/test_results.log" 2>&1; then
    log "${GREEN}✅ Tests passed${NC}"
else
    log "${RED}❌ Tests failed${NC}"
    
    # Extract test failures
    log "${RED}Test failures:${NC}"
    grep -E "Test Case.*failed|❌" "$TEMP_DIR/test_results.log" | head -10 | while read line; do
        log "  $line"
    done
fi

# Step 8: Verify Core Data model consistency
log "${YELLOW}8. Verifying Core Data model consistency...${NC}"

# Check if Core Data entities were generated correctly
CORE_DATA_ENTITIES=("Project" "Pattern" "Track" "Kit" "Preset" "Trig")
for entity in "${CORE_DATA_ENTITIES[@]}"; do
    if find "$DERIVED_DATA_PATH" -name "*${entity}+CoreDataClass.swift" | grep -q .; then
        log "${GREEN}✅ Core Data entity generated: $entity${NC}"
    else
        log "${RED}❌ Core Data entity missing: $entity${NC}"
    fi
done

# Step 9: Generate build report
log "${YELLOW}9. Generating build report...${NC}"

BUILD_REPORT="$TEMP_DIR/BUILD_REPORT.md"
cat > "$BUILD_REPORT" <<EOF
# Clean Build Simulation Report

**Date:** $(date)
**Build Environment:** Clean simulation of Xcode Cloud
**Derived Data Path:** $DERIVED_DATA_PATH

## Build Summary

### Debug Build
$(if [[ -f "$TEMP_DIR/xcodebuild.log" ]]; then
    if grep -q "BUILD SUCCEEDED" "$TEMP_DIR/xcodebuild.log"; then
        echo "✅ **SUCCESS**"
    else
        echo "❌ **FAILED**"
        echo ""
        echo "**Errors:**"
        grep -E "error:|fatal error:" "$TEMP_DIR/xcodebuild.log" | head -10 | sed 's/^/- /'
    fi
fi)

### Release Build
$(if [[ -f "$TEMP_DIR/release_build.log" ]]; then
    if grep -q "BUILD SUCCEEDED" "$TEMP_DIR/release_build.log"; then
        echo "✅ **SUCCESS**"
    else
        echo "❌ **FAILED**"
        echo ""
        echo "**Errors:**"
        grep -E "error:|fatal error:" "$TEMP_DIR/release_build.log" | head -10 | sed 's/^/- /'
    fi
fi)

### Test Results
$(if [[ -f "$TEMP_DIR/test_results.log" ]]; then
    if grep -q "Test Suite.*passed" "$TEMP_DIR/test_results.log"; then
        echo "✅ **ALL TESTS PASSED**"
    else
        echo "❌ **TESTS FAILED**"
        echo ""
        echo "**Failed Tests:**"
        grep -E "Test Case.*failed" "$TEMP_DIR/test_results.log" | head -10 | sed 's/^/- /'
    fi
fi)

### Core Data Model Validation
$(for entity in "${CORE_DATA_ENTITIES[@]}"; do
    if find "$DERIVED_DATA_PATH" -name "*${entity}+CoreDataClass.swift" | grep -q .; then
        echo "- ✅ $entity: Generated"
    else
        echo "- ❌ $entity: Missing"
    fi
done)

## Build Artifacts

- Build log: $TEMP_DIR/xcodebuild.log
- Release build log: $TEMP_DIR/release_build.log
- Test results: $TEMP_DIR/test_results.log
- Derived data: $DERIVED_DATA_PATH

## Recommendations

1. **If build failed:** Check for differences between local and CI environments
2. **If tests failed:** Run tests individually to isolate issues
3. **If Core Data issues:** Verify model file integrity and entity generation settings
4. **If dependency issues:** Check Package.swift and project.yml consistency

EOF

# Copy build report to project root
cp "$BUILD_REPORT" "./CLEAN_BUILD_REPORT.md"

log "${GREEN}✅ Clean build simulation completed${NC}"
log "${BLUE}📄 Build report saved to: ./CLEAN_BUILD_REPORT.md${NC}"
log "${BLUE}📋 Full logs available in: $TEMP_DIR${NC}"

# Ask user if they want to keep the temporary files
read -p "Keep temporary build files for inspection? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Don't cleanup, cancel the trap
    trap - EXIT
    log "${YELLOW}Temporary files preserved at: $TEMP_DIR${NC}"
else
    log "${YELLOW}Temporary files will be cleaned up${NC}"
fi