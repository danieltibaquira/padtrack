#!/bin/bash

# Local Validation Script for PadTrack
# This script runs the same validations as GitHub Actions locally

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
XCODE_VERSION="15.4"
IOS_DEPLOYMENT_TARGET="16.0"
PROJECT_NAME="DigitonePad"

# Validation results
RESULTS_DIR="validation_results_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$RESULTS_DIR"

# Log function
log() {
    echo -e "$1" | tee -a "$RESULTS_DIR/validation.log"
}

# Check function
check_command() {
    if command -v $1 &> /dev/null; then
        log "${GREEN}✓ $1 is installed${NC}"
        return 0
    else
        log "${RED}✗ $1 is not installed${NC}"
        return 1
    fi
}

# Header
log "${YELLOW}=== PadTrack Local Validation ===${NC}"
log "Results will be saved to: $RESULTS_DIR"
log ""

# 1. Environment Check
log "${YELLOW}1. Checking Environment...${NC}"
check_command xcodebuild
check_command swift
check_command xcodegen
check_command swiftlint || log "${YELLOW}  Installing swiftlint...${NC}" && brew install swiftlint

# Check Xcode version
CURRENT_XCODE=$(xcodebuild -version | head -1 | cut -d' ' -f2)
log "Xcode version: $CURRENT_XCODE"

# 2. Project Structure Validation
log ""
log "${YELLOW}2. Validating Project Structure...${NC}"

# Check for required directories
REQUIRED_MODULES=(
    "MachineProtocols" "DataModel" "DataLayer" "AudioEngine" 
    "VoiceModule" "FilterModule" "FilterMachine" "FXModule" 
    "MIDIModule" "UIComponents" "SequencerModule" "AppShell" "DigitonePad"
)

for module in "${REQUIRED_MODULES[@]}"; do
    if [ -d "Sources/$module" ]; then
        log "${GREEN}✓ Found Sources/$module${NC}"
    else
        log "${RED}✗ Missing Sources/$module${NC}"
    fi
done

# 3. Swift Syntax Check
log ""
log "${YELLOW}3. Running Swift Syntax Check...${NC}"

SYNTAX_ERRORS=0
find Sources Tests -name "*.swift" -type f | while read file; do
    if ! swiftc -parse -suppress-warnings "$file" 2>/dev/null; then
        log "${RED}✗ Syntax error in: $file${NC}"
        swiftc -parse "$file" 2>&1 | head -10 >> "$RESULTS_DIR/syntax_errors.log"
        ((SYNTAX_ERRORS++))
    fi
done

if [ $SYNTAX_ERRORS -eq 0 ]; then
    log "${GREEN}✓ All Swift files have valid syntax${NC}"
else
    log "${RED}✗ Found $SYNTAX_ERRORS files with syntax errors${NC}"
fi

# 4. Generate Xcode Project
log ""
log "${YELLOW}4. Generating Xcode Project...${NC}"

if xcodegen generate --spec project.yml > "$RESULTS_DIR/xcodegen.log" 2>&1; then
    log "${GREEN}✓ Xcode project generated successfully${NC}"
else
    log "${RED}✗ Failed to generate Xcode project${NC}"
    cat "$RESULTS_DIR/xcodegen.log"
fi

# 5. Swift Package Resolution
log ""
log "${YELLOW}5. Resolving Swift Packages...${NC}"

if swift package resolve > "$RESULTS_DIR/package_resolve.log" 2>&1; then
    log "${GREEN}✓ Package dependencies resolved${NC}"
else
    log "${RED}✗ Failed to resolve package dependencies${NC}"
    tail -20 "$RESULTS_DIR/package_resolve.log"
fi

# 6. Module Compilation Check
log ""
log "${YELLOW}6. Checking Module Compilation...${NC}"

for module in "${REQUIRED_MODULES[@]}"; do
    log "Building $module..."
    if swift build --target "$module" > "$RESULTS_DIR/build_$module.log" 2>&1; then
        log "${GREEN}✓ $module compiled successfully${NC}"
    else
        log "${RED}✗ $module compilation failed${NC}"
        # Extract specific errors
        grep -E "error:|warning:" "$RESULTS_DIR/build_$module.log" | head -10 | while read line; do
            log "  $line"
        done
    fi
done

# 7. iPad Build Validation
log ""
log "${YELLOW}7. Validating iPad Build Configuration...${NC}"

# Check if project is configured for iPad
if [ -f "DigitonePad.xcodeproj/project.pbxproj" ]; then
    if grep -q "TARGETED_DEVICE_FAMILY.*2" "DigitonePad.xcodeproj/project.pbxproj"; then
        log "${GREEN}✓ Project is configured for iPad${NC}"
    else
        log "${RED}✗ Project not configured for iPad${NC}"
    fi
else
    log "${RED}✗ Xcode project file not found${NC}"
fi

# 8. Build for iPad Simulator
log ""
log "${YELLOW}8. Building for iPad Simulator...${NC}"

if [ -f "DigitonePad.xcodeproj/project.pbxproj" ]; then
    if xcodebuild -project DigitonePad.xcodeproj \
        -scheme DigitonePad \
        -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=17.5' \
        -configuration Debug \
        clean build \
        CODE_SIGN_IDENTITY="" \
        CODE_SIGNING_REQUIRED=NO \
        > "$RESULTS_DIR/ipad_simulator_build.log" 2>&1; then
        log "${GREEN}✓ iPad Simulator build succeeded${NC}"
    else
        log "${RED}✗ iPad Simulator build failed${NC}"
        # Extract errors
        grep -E "error:|failed" "$RESULTS_DIR/ipad_simulator_build.log" | tail -20
    fi
fi

# 9. Audio Engine Validation
log ""
log "${YELLOW}9. Validating Audio Engine Configuration...${NC}"

# Check for AVAudioSession configuration
if grep -r "AVAudioSession" Sources/AudioEngine/ | grep -q "setCategory"; then
    log "${GREEN}✓ AVAudioSession configuration found${NC}"
else
    log "${YELLOW}⚠ No AVAudioSession category configuration found${NC}"
fi

# Check for real-time constraints
if grep -r "DispatchQueue\|NSLock\|@synchronized" Sources/AudioEngine/ Sources/VoiceModule/ | grep -v "// TESTING" > /dev/null; then
    log "${YELLOW}⚠ Found potential locks in audio processing code${NC}"
else
    log "${GREEN}✓ No obvious locks in audio processing path${NC}"
fi

# 10. Core Data Validation
log ""
log "${YELLOW}10. Validating Core Data Model...${NC}"

MODEL_PATH=$(find . -name "*.xcdatamodeld" -type d | head -1)
if [ -n "$MODEL_PATH" ]; then
    log "${GREEN}✓ Found Core Data model at: $MODEL_PATH${NC}"
    
    # Check for required entities
    CONTENTS_FILE=$(find "$MODEL_PATH" -name "contents" | head -1)
    if [ -f "$CONTENTS_FILE" ]; then
        required_entities=("Project" "Kit" "Pattern" "Track" "Preset" "Trig")
        for entity in "${required_entities[@]}"; do
            if grep -q "name=\"$entity\"" "$CONTENTS_FILE"; then
                log "${GREEN}✓ Found entity: $entity${NC}"
            else
                log "${RED}✗ Missing entity: $entity${NC}"
            fi
        done
    fi
else
    log "${RED}✗ No Core Data model found${NC}"
fi

# 11. Dependency Analysis
log ""
log "${YELLOW}11. Analyzing Module Dependencies...${NC}"

python3 - <<EOF > "$RESULTS_DIR/dependencies.json"
import os
import re
import json

def find_imports(file_path):
    imports = set()
    try:
        with open(file_path, 'r') as f:
            content = f.read()
            import_pattern = r'import\s+(\w+)'
            imports.update(re.findall(import_pattern, content))
    except:
        pass
    return imports

def analyze_module(module_path):
    module_name = os.path.basename(module_path)
    imports = set()
    
    for root, dirs, files in os.walk(module_path):
        for file in files:
            if file.endswith('.swift'):
                file_path = os.path.join(root, file)
                imports.update(find_imports(file_path))
    
    # Remove self-imports and system imports
    imports.discard(module_name)
    system_modules = {'Foundation', 'UIKit', 'SwiftUI', 'Combine', 'AVFoundation', 'CoreData', 'CoreMIDI', 'os'}
    imports = imports - system_modules
    
    return {
        'module': module_name,
        'dependencies': list(imports)
    }

# Analyze all modules
results = []
for module in os.listdir('Sources'):
    module_path = os.path.join('Sources', module)
    if os.path.isdir(module_path):
        results.append(analyze_module(module_path))

print(json.dumps(results, indent=2))
EOF

log "${GREEN}✓ Dependency analysis completed${NC}"

# 12. SwiftLint Check
log ""
log "${YELLOW}12. Running SwiftLint...${NC}"

if swiftlint --reporter json > "$RESULTS_DIR/swiftlint.json" 2>&1; then
    LINT_COUNT=$(cat "$RESULTS_DIR/swiftlint.json" | grep -o '"severity"' | wc -l)
    if [ $LINT_COUNT -eq 0 ]; then
        log "${GREEN}✓ No linting issues found${NC}"
    else
        log "${YELLOW}⚠ Found $LINT_COUNT linting issues${NC}"
    fi
else
    log "${RED}✗ SwiftLint failed${NC}"
fi

# 13. Test Execution
log ""
log "${YELLOW}13. Running Tests...${NC}"

if swift test > "$RESULTS_DIR/test_results.log" 2>&1; then
    log "${GREEN}✓ All tests passed${NC}"
else
    log "${YELLOW}⚠ Some tests failed${NC}"
    grep -E "failed|error:" "$RESULTS_DIR/test_results.log" | tail -10
fi

# Generate Summary Report
log ""
log "${YELLOW}Generating Summary Report...${NC}"

cat > "$RESULTS_DIR/VALIDATION_SUMMARY.md" <<EOF
# PadTrack Validation Summary

**Date:** $(date)
**Xcode Version:** $CURRENT_XCODE

## Validation Results

### ✅ Passed Checks
$(grep "✓" "$RESULTS_DIR/validation.log" | sed 's/^/- /')

### ❌ Failed Checks
$(grep "✗" "$RESULTS_DIR/validation.log" | sed 's/^/- /')

### ⚠️ Warnings
$(grep "⚠" "$RESULTS_DIR/validation.log" | sed 's/^/- /')

## Build Errors Summary

### Module Compilation Status
EOF

for module in "${REQUIRED_MODULES[@]}"; do
    if [ -f "$RESULTS_DIR/build_$module.log" ]; then
        ERROR_COUNT=$(grep -c "error:" "$RESULTS_DIR/build_$module.log" || true)
        if [ $ERROR_COUNT -eq 0 ]; then
            echo "- ✅ $module: Success" >> "$RESULTS_DIR/VALIDATION_SUMMARY.md"
        else
            echo "- ❌ $module: $ERROR_COUNT errors" >> "$RESULTS_DIR/VALIDATION_SUMMARY.md"
        fi
    fi
done

cat >> "$RESULTS_DIR/VALIDATION_SUMMARY.md" <<EOF

## Detailed Error Logs

All detailed logs are available in: $RESULTS_DIR/

### Key Files:
- validation.log - Main validation output
- syntax_errors.log - Swift syntax errors
- ipad_simulator_build.log - iPad build log
- dependencies.json - Module dependency graph
- swiftlint.json - Linting results
- test_results.log - Test execution results

## Next Steps

1. Review and fix compilation errors in failing modules
2. Resolve any syntax errors found
3. Update project configuration for iPad if needed
4. Fix any circular dependencies
5. Address SwiftLint warnings
6. Ensure all tests pass

EOF

log ""
log "${GREEN}Validation complete! Summary saved to: $RESULTS_DIR/VALIDATION_SUMMARY.md${NC}"

# Open the summary in default text editor
if command -v open &> /dev/null; then
    open "$RESULTS_DIR/VALIDATION_SUMMARY.md"
fi