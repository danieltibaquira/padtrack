#!/bin/bash

# Simple build test script for DigitonePad
# Tests both Swift CLI and xcodebuild

echo "🔄 Starting DigitonePad Build Validation..."
echo "Timestamp: $(date)"
echo "Working Directory: $(pwd)"
echo ""

# Test 1: Check if we can find Swift
echo "📋 Test 1: Swift CLI Availability"
if command -v swift &> /dev/null; then
    echo "✅ Swift CLI found: $(swift --version | head -1)"
else
    echo "❌ Swift CLI not found"
fi
echo ""

# Test 2: Check if we can find xcodebuild
echo "📋 Test 2: Xcodebuild Availability"
if command -v xcodebuild &> /dev/null; then
    echo "✅ xcodebuild found: $(xcodebuild -version | head -1)"
else
    echo "❌ xcodebuild not found"
fi
echo ""

# Test 3: Check project structure
echo "📋 Test 3: Project Structure"
if [ -f "DigitonePad.xcodeproj/project.pbxproj" ]; then
    echo "✅ Xcode project found"
else
    echo "❌ Xcode project not found"
fi

if [ -f "Package.swift" ]; then
    echo "✅ Swift Package found"
else
    echo "❌ Swift Package not found"
fi
echo ""

# Test 4: Check key source files
echo "📋 Test 4: Key Source Files"
key_files=(
    "Sources/MachineProtocols/MachineProtocols.swift"
    "Sources/VoiceModule/FMDrumVoiceMachine.swift"
    "Sources/AudioEngine/AudioEngine.swift"
    "Tests/VoiceModuleTests/FMDrumVoiceMachineTests.swift"
)

for file in "${key_files[@]}"; do
    if [ -f "$file" ]; then
        echo "✅ $file exists"
    else
        echo "❌ $file missing"
    fi
done
echo ""

# Test 5: Try Swift build (if available)
echo "📋 Test 5: Swift Build Test"
if command -v swift &> /dev/null; then
    echo "🔄 Attempting swift build..."
    if timeout 60 swift build 2>&1; then
        echo "✅ Swift build successful"
    else
        echo "❌ Swift build failed or timed out"
    fi
else
    echo "⏭️ Skipping swift build (CLI not available)"
fi
echo ""

# Test 6: Try xcodebuild (if available)
echo "📋 Test 6: Xcodebuild Test"
if command -v xcodebuild &> /dev/null && [ -f "DigitonePad.xcodeproj/project.pbxproj" ]; then
    echo "🔄 Attempting xcodebuild..."
    if timeout 120 xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination 'platform=iOS Simulator,name=iPad Air (5th generation)' build 2>&1; then
        echo "✅ Xcodebuild successful"
    else
        echo "❌ Xcodebuild failed or timed out"
    fi
else
    echo "⏭️ Skipping xcodebuild (not available or project missing)"
fi
echo ""

echo "🏁 Build validation complete!"
echo "Timestamp: $(date)"
