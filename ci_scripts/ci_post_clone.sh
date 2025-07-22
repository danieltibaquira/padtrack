#!/bin/bash

# Xcode Cloud Post-Clone Script
# Runs immediately after cloning the repository

set -e  # Exit on any error

echo "🔄 Starting Xcode Cloud Post-Clone Script"

# Display environment information
echo "🌍 Environment Information:"
echo "   CI_XCODE_CLOUD: $CI_XCODE_CLOUD"
echo "   CI_WORKSPACE: $CI_WORKSPACE"
echo "   CI_PRIMARY_REPOSITORY_PATH: $CI_PRIMARY_REPOSITORY_PATH"
echo "   Working Directory: $(pwd)"

# Change to repository directory
cd "$CI_PRIMARY_REPOSITORY_PATH"

# Display repository information
echo "📂 Repository Information:"
echo "   Branch: $CI_BRANCH"
echo "   Commit: $CI_COMMIT"
echo "   Repository: $CI_REPOSITORY"

# Install system dependencies
echo "📦 Installing system dependencies..."

# Update Homebrew
echo "🍺 Updating Homebrew..."
brew update

# Install xcodegen (required for project generation)
echo "📥 Installing xcodegen..."
brew install xcodegen

# Verify installation
echo "✅ Verifying installations:"
xcodegen --version

# Display repository structure
echo "📁 Repository structure:"
ls -la

# Verify required files exist
echo "🔍 Verifying required files:"
if [[ -f "project.yml" ]]; then
    echo "✅ project.yml found"
else
    echo "❌ project.yml not found!"
    exit 1
fi

if [[ -f "Package.swift" ]]; then
    echo "✅ Package.swift found"
else
    echo "⚠️  Package.swift not found (may be expected)"
fi

# Check Swift Package structure
echo "📦 Swift Package modules:"
if [[ -d "Sources" ]]; then
    ls -la Sources/
else
    echo "⚠️  Sources directory not found"
fi

echo "✅ Post-clone script completed successfully"