#!/bin/bash

# DigitonePad Compilation Check Script
# Validates Swift files for common compilation issues

set -e

echo "🔍 DigitonePad Compilation Check"
echo "================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
total_files=0
issues_found=0

# Function to check a Swift file for common issues
check_swift_file() {
    local file="$1"
    local file_issues=0
    
    echo -n "📄 $(basename "$file")... "
    
    # Check for duplicate imports
    duplicate_imports=$(grep -n "^import " "$file" | sort | uniq -d -f1)
    if [ ! -z "$duplicate_imports" ]; then
        echo -e "${RED}❌${NC}"
        echo "  ⚠️  Duplicate imports found:"
        echo "$duplicate_imports" | sed 's/^/     /'
        file_issues=$((file_issues + 1))
    fi
    
    # Check for common syntax issues
    if grep -q "import.*import" "$file"; then
        if [ $file_issues -eq 0 ]; then echo -e "${RED}❌${NC}"; fi
        echo "  ⚠️  Possible malformed import statement"
        file_issues=$((file_issues + 1))
    fi
    
    # Check for basic Swift syntax errors
    if grep -q "class.*{$" "$file" && ! grep -q "}" "$file"; then
        if [ $file_issues -eq 0 ]; then echo -e "${RED}❌${NC}"; fi
        echo "  ⚠️  Possible unclosed class bracket"
        file_issues=$((file_issues + 1))
    fi
    
    # Check for incomplete function signatures
    if grep -q "func.*{$" "$file" && grep -c "func" "$file" | grep -q "^[1-9]"; then
        incomplete_funcs=$(grep -n "func.*->.*{$" "$file" | grep -v "return")
        if [ ! -z "$incomplete_funcs" ]; then
            if [ $file_issues -eq 0 ]; then echo -e "${YELLOW}⚠️${NC}"; fi
            echo "  ℹ️  Functions may need implementation (TODO is okay)"
            file_issues=$((file_issues + 1))
        fi
    fi
    
    if [ $file_issues -eq 0 ]; then
        echo -e "${GREEN}✅${NC}"
    fi
    
    return $file_issues
}

# Function to check module consistency
check_module_consistency() {
    echo -e "\n📦 Checking module consistency..."
    
    # Check that all modules have their main files
    modules=("MachineProtocols" "DataModel" "DataLayer" "AudioEngine" "VoiceModule" "FilterModule" "FilterMachine" "FXModule" "MIDIModule" "UIComponents" "SequencerModule" "AppShell" "DigitonePad")
    
    for module in "${modules[@]}"; do
        echo -n "  📁 $module... "
        if [ -d "Sources/$module" ]; then
            # Check for at least one Swift file
            swift_files=$(find "Sources/$module" -name "*.swift" | wc -l)
            if [ $swift_files -gt 0 ]; then
                echo -e "${GREEN}✅${NC} ($swift_files files)"
            else
                echo -e "${RED}❌${NC} (no Swift files)"
                issues_found=$((issues_found + 1))
            fi
        else
            echo -e "${RED}❌${NC} (directory missing)"
            issues_found=$((issues_found + 1))
        fi
    done
}

# Function to check Package.swift
check_package_swift() {
    echo -e "\n📦 Checking Package.swift..."
    
    if [ ! -f "Package.swift" ]; then
        echo -e "${RED}❌${NC} Package.swift not found"
        issues_found=$((issues_found + 1))
        return
    fi
    
    echo -n "  📄 Syntax check... "
    
    # Basic syntax checks
    if ! grep -q "swift-tools-version" "Package.swift"; then
        echo -e "${RED}❌${NC} Missing swift-tools-version"
        issues_found=$((issues_found + 1))
        return
    fi
    
    if ! grep -q "Package(" "Package.swift"; then
        echo -e "${RED}❌${NC} Missing Package declaration"
        issues_found=$((issues_found + 1))
        return
    fi
    
    echo -e "${GREEN}✅${NC}"
    
    # Check target consistency
    echo -n "  🎯 Target consistency... "
    declared_targets=$(grep -o '\.target([^)]*name: *"[^"]*"' "Package.swift" | grep -o '"[^"]*"' | tr -d '"')
    
    for target in $declared_targets; do
        if [ ! -d "Sources/$target" ]; then
            echo -e "${RED}❌${NC}"
            echo "    ⚠️  Target '$target' declared but directory missing"
            issues_found=$((issues_found + 1))
            return
        fi
    done
    
    echo -e "${GREEN}✅${NC}"
}

# Function to check imports and dependencies
check_imports_and_dependencies() {
    echo -e "\n🔗 Checking imports and dependencies..."
    
    # Check for common import issues
    echo -n "  📚 Import analysis... "
    
    # Find all imports
    all_imports=$(find Sources -name "*.swift" -exec grep -h "^import " {} \; | sort | uniq)
    
    # Check for potentially missing imports
    suspicious_files=0
    
    while IFS= read -r file; do
        # Check if file uses AVFoundation types without importing
        if grep -q "AVAudio\|AVAudio\|CMTime" "$file" && ! grep -q "import AVFoundation" "$file"; then
            if [ $suspicious_files -eq 0 ]; then
                echo -e "${YELLOW}⚠️${NC}"
                echo "    Files possibly missing AVFoundation import:"
            fi
            echo "      $(basename "$file")"
            suspicious_files=$((suspicious_files + 1))
        fi
        
        # Check if file uses SwiftUI types without importing
        if grep -q "View\|@State\|@Published" "$file" && ! grep -q "import SwiftUI" "$file" && ! grep -q "import Combine" "$file"; then
            if [ $suspicious_files -eq 0 ]; then
                echo -e "${YELLOW}⚠️${NC}"
                echo "    Files possibly missing SwiftUI/Combine import:"
            fi
            echo "      $(basename "$file")"
            suspicious_files=$((suspicious_files + 1))
        fi
    done < <(find Sources -name "*.swift")
    
    if [ $suspicious_files -eq 0 ]; then
        echo -e "${GREEN}✅${NC}"
    fi
}

# Function to check for protocol conformance issues
check_protocol_conformance() {
    echo -e "\n🔌 Checking protocol conformance..."
    
    # Find classes that claim to conform to protocols
    echo -n "  🏷️  Protocol implementations... "
    
    protocol_issues=0
    
    # Check VoiceMachineProtocol conformance
    voice_machines=$(grep -l "VoiceMachineProtocol" Sources/VoiceModule/*.swift 2>/dev/null || true)
    for file in $voice_machines; do
        if [ -f "$file" ]; then
            # Check for required properties
            required_props=("masterVolume" "masterTuning" "polyphony" "activeVoices")
            for prop in "${required_props[@]}"; do
                if ! grep -q "var $prop" "$file"; then
                    if [ $protocol_issues -eq 0 ]; then
                        echo -e "${YELLOW}⚠️${NC}"
                        echo "    Missing VoiceMachineProtocol requirements:"
                    fi
                    echo "      $(basename "$file"): missing $prop"
                    protocol_issues=$((protocol_issues + 1))
                fi
            done
        fi
    done
    
    # Check FilterMachineProtocol conformance
    filter_machines=$(grep -l "FilterMachineProtocol" Sources/FilterModule/*.swift 2>/dev/null || true)
    for file in $filter_machines; do
        if [ -f "$file" ]; then
            # Check for required properties
            required_props=("cutoff" "resonance" "filterType")
            for prop in "${required_props[@]}"; do
                if ! grep -q "var $prop" "$file"; then
                    if [ $protocol_issues -eq 0 ]; then
                        echo -e "${YELLOW}⚠️${NC}"
                        echo "    Missing FilterMachineProtocol requirements:"
                    fi
                    echo "      $(basename "$file"): missing $prop"
                    protocol_issues=$((protocol_issues + 1))
                fi
            done
        fi
    done
    
    if [ $protocol_issues -eq 0 ]; then
        echo -e "${GREEN}✅${NC}"
    fi
}

# Main execution
echo "Starting compilation check..."
echo

# Check Package.swift first
check_package_swift

# Check module consistency
check_module_consistency

# Check each Swift file
echo -e "\n🔍 Checking individual Swift files..."
while IFS= read -r file; do
    check_swift_file "$file"
    if [ $? -gt 0 ]; then
        issues_found=$((issues_found + 1))
    fi
    total_files=$((total_files + 1))
done < <(find Sources -name "*.swift" | head -20)  # Limit to first 20 files for performance

if [ $total_files -gt 20 ]; then
    echo "  📊 Checked first 20 of $total_files Swift files for performance"
fi

# Check imports and dependencies
check_imports_and_dependencies

# Check protocol conformance
check_protocol_conformance

# Summary
echo -e "\n📊 Summary"
echo "=========="
echo "📄 Files checked: $total_files"
echo "⚠️  Issues found: $issues_found"

if [ $issues_found -eq 0 ]; then
    echo -e "${GREEN}🎉 No critical compilation issues detected!${NC}"
    echo -e "${BLUE}💡 Ready for Swift compilation with 'swift build'${NC}"
    exit 0
else
    echo -e "${YELLOW}⚠️  Some potential issues detected${NC}"
    echo -e "${BLUE}💡 Review issues above before compilation${NC}"
    exit 1
fi