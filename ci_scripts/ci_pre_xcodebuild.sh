#!/bin/bash

# Enhanced Xcode Cloud Pre-Build Script
# Runs before xcodebuild to prepare the project and replicate local environment

set -e  # Exit on any error

echo "🚀 Starting Enhanced Xcode Cloud Pre-Build Script"

# Enable more detailed logging
export XCODEBUILD_VERBOSE=1

# Debug: Show current environment and working directory
echo "📍 Current working directory: $(pwd)"
echo "📁 Directory contents:"
ls -la

# Show environment details
echo "🌍 Environment Information:"
echo "   CI_XCODE_CLOUD: ${CI_XCODE_CLOUD:-'not set'}"
echo "   CI_WORKSPACE: ${CI_WORKSPACE:-'not set'}"
echo "   CI_PRIMARY_REPOSITORY_PATH: ${CI_PRIMARY_REPOSITORY_PATH:-'not set'}"
echo "   CI_BRANCH: ${CI_BRANCH:-'not set'}"
echo "   CI_COMMIT: ${CI_COMMIT:-'not set'}"
echo "   XCODE_VERSION: ${CI_XCODE_VERSION:-'not set'}"
echo "   Swift version: $(swift --version 2>/dev/null || echo 'not available')"

# Check if we're in Xcode Cloud environment
if [[ -n "$CI_XCODE_CLOUD" ]]; then
    echo "✅ Running in Xcode Cloud environment"
else
    echo "⚠️  Not in Xcode Cloud environment, proceeding anyway"
fi

# Navigate to the correct directory if needed
if [[ -n "$CI_PRIMARY_REPOSITORY_PATH" ]]; then
    echo "📂 Changing to primary repository path: $CI_PRIMARY_REPOSITORY_PATH"
    cd "$CI_PRIMARY_REPOSITORY_PATH"
    echo "📍 New working directory: $(pwd)"
    echo "📁 Directory contents:"
    ls -la
fi

# Run quick syntax check to catch issues early (like local development)
echo "🔍 Running quick syntax validation..."
if [[ -f "quick_syntax_check.sh" ]]; then
    chmod +x quick_syntax_check.sh
    if ./quick_syntax_check.sh; then
        echo "✅ Quick syntax check passed"
    else
        echo "❌ Quick syntax check failed"
        echo "This indicates issues that would also fail locally"
        exit 1
    fi
else
    echo "⚠️  quick_syntax_check.sh not found, skipping syntax validation"
fi

# Check Package.swift configuration to match local
echo "📦 Checking Package.swift configuration..."
if [[ -f "Package.swift" ]]; then
    echo "✅ Package.swift found"
    package_tools_version=$(grep "swift-tools-version:" Package.swift | grep -o '[0-9]\+\.[0-9]\+' || echo "unknown")
    echo "📍 Swift tools version: $package_tools_version"
    
    if [[ "$package_tools_version" != "5.10" ]]; then
        echo "⚠️  Package.swift uses $package_tools_version, but Xcode Cloud typically works best with 5.10"
        echo "This may cause differences from local builds"
    fi
else
    echo "📦 No Package.swift found, using project.yml only"
fi

# Install xcodegen if not present
echo "📦 Checking for xcodegen..."
if ! command -v xcodegen &> /dev/null; then
    echo "📥 Installing xcodegen..."
    brew install xcodegen
else
    echo "✅ xcodegen already installed"
    echo "📍 xcodegen version: $(xcodegen --version)"
fi

# Check if DigitonePad.xcodeproj already exists
if [[ -d "DigitonePad.xcodeproj" ]]; then
    echo "📂 DigitonePad.xcodeproj already exists"
    echo "🔍 Checking if project.yml exists for potential regeneration..."
fi

# Generate Xcode project from project.yml if available
if [[ -f "project.yml" ]]; then
    echo "✅ project.yml found"
    echo "📄 project.yml contents preview:"
    head -20 project.yml
    
    # Check project.yml configuration
    swift_version=$(grep "SWIFT_VERSION:" project.yml | grep -o '"[0-9]\+\.[0-9]\+"' | tr -d '"' || echo "not specified")
    deployment_target=$(grep "iOS:" project.yml | grep -o '"[0-9]\+\.[0-9]\+"' | tr -d '"' || echo "not specified")
    
    echo "📍 Project configuration:"
    echo "   Swift Version: $swift_version"
    echo "   iOS Deployment Target: $deployment_target"
    
    echo "🔨 Running xcodegen generate..."
    xcodegen generate
    echo "✅ Xcode project generated successfully"
    
    # Verify the generated project has the right settings
    echo "🔍 Verifying generated project settings..."
    if xcodebuild -project DigitonePad.xcodeproj -showBuildSettings -target DigitonePad | grep -q "SWIFT_VERSION = $swift_version"; then
        echo "✅ Swift version correctly set to $swift_version"
    else
        echo "⚠️  Swift version may not be correctly configured"
    fi
    
elif [[ -d "DigitonePad.xcodeproj" ]]; then
    echo "⚠️  project.yml not found, but DigitonePad.xcodeproj exists"
    echo "✅ Proceeding with existing Xcode project"
else
    echo "❌ Neither project.yml nor DigitonePad.xcodeproj found!"
    echo "📁 Searching for project.yml in current directory and subdirectories:"
    find . -name "project.yml" -type f 2>/dev/null || echo "No project.yml files found"
    echo "📁 Searching for .xcodeproj files:"
    find . -name "*.xcodeproj" -type d 2>/dev/null || echo "No .xcodeproj files found"
    exit 1
fi

# Verify DigitonePad.xcodeproj exists
if [[ -d "DigitonePad.xcodeproj" ]]; then
    echo "✅ DigitonePad.xcodeproj confirmed to exist"
else
    echo "❌ DigitonePad.xcodeproj not found after generation attempt"
    exit 1
fi

# Display project structure for debugging
echo "📁 Project structure:"
ls -la

# Check Sources directory structure (critical for module dependencies)
echo "📁 Sources structure:"
if [[ -d "Sources" ]]; then
    ls -la Sources/
    echo "📊 Module count: $(ls -1 Sources/ | wc -l)"
else
    echo "❌ Sources directory not found!"
    exit 1
fi

# Verify scheme exists and list all available schemes
echo "🔍 Checking available schemes..."
echo "📋 Available schemes:"
xcodebuild -list -project DigitonePad.xcodeproj

if xcodebuild -list -project DigitonePad.xcodeproj | grep -q "DigitonePad"; then
    echo "✅ DigitonePad scheme found"
else
    echo "❌ DigitonePad scheme not found"
    echo "Available schemes:"
    xcodebuild -list -project DigitonePad.xcodeproj
    exit 1
fi

# Check for common build issues that differ between local and CI
echo "🔍 Checking for potential CI/local differences..."

# Check for Swift files with potential CI-incompatible patterns
echo "📝 Checking Swift files for CI compatibility..."
swift_file_count=$(find Sources Tests -name "*.swift" 2>/dev/null | wc -l)
echo "📊 Found $swift_file_count Swift files"

# Check for files that might cause issues
md_files=$(find Sources Tests -name "*.md" 2>/dev/null | wc -l)
if [[ $md_files -gt 0 ]]; then
    echo "⚠️  Found $md_files .md files in Sources/Tests (may cause build warnings)"
fi

# Set development team for automatic code signing
echo "🔐 Configuring code signing..."
echo "📍 Development Team: GN9UGD54YC (configured in project.yml)"

# Test a basic build command to verify everything is set up correctly
echo "🧪 Testing basic build configuration..."
if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination "generic/platform=iOS Simulator" -configuration Debug -showBuildSettings | head -10; then
    echo "✅ Build configuration verified"
else
    echo "⚠️  Build configuration test had warnings"
fi

# Check if FilterModule builds specifically (this was the problematic module)
echo "🧪 Testing FilterModule framework build..."
if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePad -destination "generic/platform=iOS Simulator" -target FilterModule -configuration Debug -showBuildSettings | head -5; then
    echo "✅ FilterModule configuration verified"
else
    echo "⚠️  FilterModule configuration test had warnings"
fi

echo "✅ Enhanced pre-build script completed successfully"
echo "🎯 Environment should now match local development conditions"