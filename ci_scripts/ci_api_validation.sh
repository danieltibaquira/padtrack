#!/bin/bash

# CI API Validation Script
# Ensures CI environment has exactly the same APIs as expected locally
# This catches API mismatches BEFORE build attempts

set -e  # Exit on any error

echo "🔍 Starting CI API Validation"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Track validation status
validation_errors=0

# Function to report validation error
report_error() {
    echo -e "${RED}❌ API VALIDATION ERROR: $1${NC}"
    ((validation_errors++))
}

# Function to report success
report_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

# 1. Validate ParameterSmoother API matches expectations
echo -e "\n${BLUE}[1/5]${NC} Validating ParameterSmoother API..."

if [[ -f "Sources/VoiceModule/ParameterSmoother.swift" ]]; then
    report_success "ParameterSmoother.swift found"
    
    # Check that ONLY these methods exist (not the broken ones)
    if grep -q "func setTarget" Sources/VoiceModule/ParameterSmoother.swift; then
        report_success "setTarget method found (correct API)"
    else
        report_error "setTarget method missing from ParameterSmoother"
    fi
    
    if grep -q "func process()" Sources/VoiceModule/ParameterSmoother.swift; then
        report_success "process() method found (correct API)"
    else
        report_error "process() method missing from ParameterSmoother"
    fi
    
    # Check that broken APIs are NOT present
    if grep -q "updateParameter\|registerParameter\|getSmoothedParameters" Sources/VoiceModule/ParameterSmoother.swift; then
        report_error "ParameterSmoother contains broken APIs that don't exist"
    else
        report_success "ParameterSmoother free of non-existent APIs"
    fi
else
    report_error "ParameterSmoother.swift not found"
fi

# 2. Validate MultiModeFilterMachine uses correct APIs
echo -e "\n${BLUE}[2/5]${NC} Validating MultiModeFilterMachine API usage..."

if [[ -f "Sources/FilterModule/MultiModeFilterMachine.swift" ]]; then
    report_success "MultiModeFilterMachine.swift found"
    
    # Check file size - should be simplified version (~184 lines, not 500+ lines)
    line_count=$(wc -l < Sources/FilterModule/MultiModeFilterMachine.swift)
    if [[ $line_count -lt 250 ]]; then
        report_success "MultiModeFilterMachine is simplified version ($line_count lines)"
    else
        report_error "MultiModeFilterMachine is complex version ($line_count lines) - should be simplified"
    fi
    
    # Check that it DOESN'T use the broken APIs
    if grep -q "updateParameter\|registerParameter\|getSmoothedParameters\|FilterParameterSmoother.*updateConfig" Sources/FilterModule/MultiModeFilterMachine.swift; then
        report_error "MultiModeFilterMachine uses non-existent ParameterSmoother APIs"
    else
        report_success "MultiModeFilterMachine free of non-existent APIs"
    fi
    
    # Check that it uses the correct alias
    if grep -q "typealias FilterParameterSmoother = ParameterSmoother" Sources/FilterModule/MultiModeFilterMachine.swift; then
        report_success "FilterParameterSmoother alias correctly defined"
    else
        report_error "FilterParameterSmoother alias missing or incorrect"
    fi
else
    report_error "MultiModeFilterMachine.swift not found"
fi

# 3. Validate KeyboardTrackingIntegration has required methods
echo -e "\n${BLUE}[3/5]${NC} Validating KeyboardTrackingIntegration API..."

if [[ -f "Sources/FilterModule/KeyboardTrackingIntegration.swift" ]]; then
    report_success "KeyboardTrackingIntegration.swift found"
    
    # Check for required static method
    if grep -q "static func midiNoteToFrequency" Sources/FilterModule/KeyboardTrackingIntegration.swift; then
        report_success "midiNoteToFrequency static method found"
    else
        report_error "midiNoteToFrequency static method missing"
    fi
    
    # Check for single protocol definition (not duplicate)
    protocol_count=$(grep -c "protocol KeyboardTrackingDelegate" Sources/FilterModule/KeyboardTrackingIntegration.swift || echo "0")
    if [[ $protocol_count -eq 1 ]]; then
        report_success "Single KeyboardTrackingDelegate protocol definition found"
    else
        report_error "Found $protocol_count KeyboardTrackingDelegate protocol definitions (should be 1)"
    fi
else
    report_error "KeyboardTrackingIntegration.swift not found"
fi

# 4. Validate FilterPerformanceOptimizer uses correct pointer access
echo -e "\n${BLUE}[4/5]${NC} Validating FilterPerformanceOptimizer API..."

if [[ -f "Sources/FilterModule/FilterPerformanceOptimizer.swift" ]]; then
    report_success "FilterPerformanceOptimizer.swift found"
    
    # Check for correct buffer access pattern
    if grep -q "withUnsafeMutableBufferPointer" Sources/FilterModule/FilterPerformanceOptimizer.swift; then
        report_success "Correct buffer access pattern found"
    else
        report_error "Correct buffer access pattern missing"
    fi
    
    # Check that it doesn't use the broken pattern
    if grep -q "\.withUnsafeBufferPointer.*input.*output" Sources/FilterModule/FilterPerformanceOptimizer.swift; then
        report_error "FilterPerformanceOptimizer uses broken UnsafePointer pattern"
    else
        report_success "FilterPerformanceOptimizer free of broken pointer patterns"
    fi
else
    report_error "FilterPerformanceOptimizer.swift not found"
fi

# 5. Validate critical type definitions exist
echo -e "\n${BLUE}[5/5]${NC} Validating critical type definitions..."

# Check for required types in FilterCoefficients
if [[ -f "Sources/FilterModule/FilterCoefficients.swift" ]]; then
    report_success "FilterCoefficients.swift found"
    
    # Check for required types
    if grep -q "struct BiquadCoefficients" Sources/FilterModule/FilterCoefficients.swift; then
        report_success "BiquadCoefficients type found"
    else
        report_error "BiquadCoefficients type missing"
    fi
    
    if grep -q "struct MachinePerformanceMetrics" Sources/MachineProtocols/MachineProtocols.swift; then
        report_success "MachinePerformanceMetrics type found"
    else
        report_error "MachinePerformanceMetrics type missing"
    fi
else
    report_error "MachineProtocols.swift not found"
fi

# Summary
echo ""
echo "========================================"
if [[ $validation_errors -eq 0 ]]; then
    echo -e "${GREEN}🎉 API Validation PASSED!${NC}"
    echo -e "${GREEN}✅ All APIs match local environment expectations${NC}"
    echo -e "${GREEN}✅ Ready for consistent CI build${NC}"
    exit 0
else
    echo -e "${RED}❌ API Validation FAILED!${NC}"
    echo -e "${RED}Found $validation_errors API inconsistencies${NC}"
    echo ""
    echo -e "${YELLOW}This indicates the CI environment has different files than local.${NC}"
    echo -e "${YELLOW}Common causes:${NC}"
    echo "  • Git commit/push mismatch"
    echo "  • Cached CI artifacts using old files"
    echo "  • Build system differences (Package.swift vs Xcode project)"
    echo "  • Import resolution differences"
    echo ""
    echo -e "${YELLOW}To fix:${NC}"
    echo "  1. Ensure latest changes are committed and pushed"
    echo "  2. Clear CI caches"
    echo "  3. Verify local build works with same commands as CI"
    echo "  4. Check for environment-specific build differences"
    exit 1
fi