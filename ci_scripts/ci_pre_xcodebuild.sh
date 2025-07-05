#!/bin/bash

# Xcode Cloud Pre-Build Script
# Runs before xcodebuild to prepare the project

set -e  # Exit on any error

echo "🚀 Starting Xcode Cloud Pre-Build Script"

# Debug: Show current environment and working directory
echo "📍 Current working directory: $(pwd)"
echo "📁 Directory contents:"
ls -la

# Check if we're in Xcode Cloud environment
if [[ -n "$CI_XCODE_CLOUD" ]]; then
    echo "✅ Running in Xcode Cloud environment"
    echo "🔍 CI_WORKSPACE: ${CI_WORKSPACE:-'not set'}"
    echo "🔍 CI_PRIMARY_REPOSITORY_PATH: ${CI_PRIMARY_REPOSITORY_PATH:-'not set'}"
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

# Install xcodegen if not present
echo "📦 Checking for xcodegen..."
if ! command -v xcodegen &> /dev/null; then
    echo "📥 Installing xcodegen..."
    brew install xcodegen
else
    echo "✅ xcodegen already installed"
    echo "📍 xcodegen version: $(xcodegen --version)"
fi

# Generate Xcode project from project.yml
echo "🔨 Generating Xcode project..."
if [[ -f "project.yml" ]]; then
    echo "✅ project.yml found"
    echo "📄 project.yml contents preview:"
    head -10 project.yml
    echo "🔨 Running xcodegen generate..."
    xcodegen generate
    echo "✅ Xcode project generated successfully"
else
    echo "❌ project.yml not found!"
    echo "📁 Searching for project.yml in current directory and subdirectories:"
    find . -name "project.yml" -type f 2>/dev/null || echo "No project.yml files found"
    exit 1
fi

# Verify DigitonePad.xcodeproj was created
if [[ -d "DigitonePad.xcodeproj" ]]; then
    echo "✅ DigitonePad.xcodeproj created successfully"
else
    echo "❌ Failed to generate DigitonePad.xcodeproj"
    exit 1
fi

# Display project structure for debugging
echo "📁 Project structure:"
ls -la

# Verify scheme exists
echo "🔍 Checking for DigitonePad scheme..."
if xcodebuild -list -project DigitonePad.xcodeproj | grep -q "DigitonePad"; then
    echo "✅ DigitonePad scheme found"
else
    echo "❌ DigitonePad scheme not found"
    xcodebuild -list -project DigitonePad.xcodeproj
    exit 1
fi

# Set development team for automatic code signing
echo "🔐 Configuring code signing..."
# This will be handled by Xcode Cloud's automatic code signing

echo "✅ Pre-build script completed successfully"