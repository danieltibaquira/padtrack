#!/bin/bash

# Xcode Cloud Post-Build Script
# Runs after successful build to perform validation and notifications

set -e  # Exit on any error

echo "🎉 Starting Xcode Cloud Post-Build Script"

# Check build status
if [[ "${CI_XCODEBUILD_EXIT_CODE:-1}" != "0" ]]; then
    echo "❌ Build failed with exit code: ${CI_XCODEBUILD_EXIT_CODE:-'unknown'}"
    echo "⚠️  Skipping post-build processing due to build failure"
    exit 1
fi

echo "✅ Build completed successfully"

# Display build information
echo "📊 Build Information:"
echo "   Branch: $CI_BRANCH"
echo "   Commit: $CI_COMMIT"
echo "   Build Number: $CI_BUILD_NUMBER"
echo "   Xcode Version: $CI_XCODE_VERSION"

# Validate that archive was created (for TestFlight builds)
if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
    echo "📦 Archive action detected"
    
    # Check for archive
    if [[ -n "$CI_ARCHIVE_PATH" ]]; then
        echo "✅ Archive created at: $CI_ARCHIVE_PATH"
        
        # Display archive information
        echo "📋 Archive contents:"
        ls -la "$CI_ARCHIVE_PATH"
    else
        echo "⚠️  Archive path not found"
    fi
fi

# Performance metrics
echo "⏱️  Build Performance:"
echo "   Start Time: ${CI_WORKFLOW_START_TIMESTAMP:-'not available'}"
if [[ -n "$CI_WORKFLOW_START_TIMESTAMP" ]]; then
    duration=$(( $(date +%s) - CI_WORKFLOW_START_TIMESTAMP ))
    echo "   Duration: $duration seconds"
else
    echo "   Duration: not available"
fi

# Success notification
echo "🚀 Build ready for TestFlight distribution!"
echo "   App: DigitonePad"
echo "   Bundle ID: com.digitonepad.app"
echo "   Team: GN9UGD54YC"

echo "✅ Post-build script completed successfully"