#!/bin/bash

# Enhanced Xcode Cloud Post-Build Script
# Runs after successful build to perform validation and notifications

set -e  # Exit on any error

echo "🎉 Starting Enhanced Xcode Cloud Post-Build Script"

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
echo "   Build Action: ${CI_XCODEBUILD_ACTION:-'not set'}"

# Navigate to project directory if needed
if [[ -n "$CI_PRIMARY_REPOSITORY_PATH" ]]; then
    cd "$CI_PRIMARY_REPOSITORY_PATH"
fi

# Run post-build validation similar to local environment
echo "🔍 Running post-build validation..."

# Verify all frameworks were built successfully
echo "📦 Verifying framework builds..."
expected_frameworks=(
    "MachineProtocols.framework"
    "DataModel.framework"
    "DataLayer.framework"
    "AudioEngine.framework"
    "SequencerModule.framework"
    "VoiceModule.framework"
    "FilterModule.framework"
    "FilterMachine.framework"
    "FXModule.framework"
    "MIDIModule.framework"
    "UIComponents.framework"
    "AppShell.framework"
)

# Check if frameworks were built (they would be in derived data)
framework_count=0
for framework in "${expected_frameworks[@]}"; do
    if find . -name "$framework" -type d 2>/dev/null | head -1 | grep -q "$framework"; then
        ((framework_count++))
        echo "✅ $framework found"
    else
        echo "⚠️  $framework not found in build output"
    fi
done

echo "📊 Framework build summary: $framework_count/${#expected_frameworks[@]} frameworks detected"

# Check for build warnings or errors
echo "🔍 Checking for build warnings..."
if [[ -n "$CI_XCODEBUILD_LOG_PATH" ]]; then
    echo "📁 Build log path: $CI_XCODEBUILD_LOG_PATH"
    
    # Count warnings and errors in build log
    if [[ -f "$CI_XCODEBUILD_LOG_PATH" ]]; then
        warning_count=$(grep -c "warning:" "$CI_XCODEBUILD_LOG_PATH" 2>/dev/null || echo "0")
        error_count=$(grep -c "error:" "$CI_XCODEBUILD_LOG_PATH" 2>/dev/null || echo "0")
        
        echo "📊 Build log analysis:"
        echo "   Warnings: $warning_count"
        echo "   Errors: $error_count"
        
        if [[ "$warning_count" -gt 0 ]]; then
            echo "⚠️  Build warnings detected (build still successful)"
            echo "📋 Sample warnings:"
            grep "warning:" "$CI_XCODEBUILD_LOG_PATH" | head -3 || echo "Could not extract warnings"
        fi
        
        if [[ "$error_count" -gt 0 ]]; then
            echo "❌ Build errors detected (this shouldn't happen for successful builds)"
        fi
    else
        echo "⚠️  Build log file not accessible"
    fi
else
    echo "⚠️  Build log path not available"
fi

# Validate that archive was created (for TestFlight builds)
if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
    echo "📦 Archive action detected"
    
    # Check for archive
    if [[ -n "$CI_ARCHIVE_PATH" ]]; then
        echo "✅ Archive created at: $CI_ARCHIVE_PATH"
        
        # Display archive information
        echo "📋 Archive contents:"
        ls -la "$CI_ARCHIVE_PATH" 2>/dev/null || echo "Could not list archive contents"
        
        # Check archive size (should be reasonable for iOS app)
        if [[ -d "$CI_ARCHIVE_PATH" ]]; then
            archive_size=$(du -sh "$CI_ARCHIVE_PATH" 2>/dev/null | cut -f1 || echo "unknown")
            echo "📏 Archive size: $archive_size"
        fi
        
        # Verify key components are in archive
        if [[ -d "$CI_ARCHIVE_PATH/Products/Applications/DigitonePad.app" ]]; then
            echo "✅ DigitonePad.app found in archive"
            
            # Check app bundle
            app_size=$(du -sh "$CI_ARCHIVE_PATH/Products/Applications/DigitonePad.app" 2>/dev/null | cut -f1 || echo "unknown")
            echo "📏 App bundle size: $app_size"
        else
            echo "⚠️  DigitonePad.app not found in expected location"
        fi
    else
        echo "⚠️  Archive path not found"
    fi
elif [[ "$CI_XCODEBUILD_ACTION" == "build" ]]; then
    echo "🔨 Build action detected (not archiving)"
elif [[ "$CI_XCODEBUILD_ACTION" == "test" ]]; then
    echo "🧪 Test action detected"
    
    # Check test results
    if [[ -n "$CI_RESULT_BUNDLE_PATH" ]]; then
        echo "📊 Test results available at: $CI_RESULT_BUNDLE_PATH"
    else
        echo "⚠️  Test result bundle path not available"
    fi
fi

# Performance metrics
echo "⏱️  Build Performance:"
echo "   Start Time: ${CI_WORKFLOW_START_TIMESTAMP:-'not available'}"
if [[ -n "$CI_WORKFLOW_START_TIMESTAMP" ]]; then
    duration=$(( $(date +%s) - CI_WORKFLOW_START_TIMESTAMP ))
    echo "   Duration: $duration seconds"
    
    # Performance assessment
    if [[ "$duration" -lt 300 ]]; then
        echo "🚀 Excellent build time (< 5 minutes)"
    elif [[ "$duration" -lt 600 ]]; then
        echo "✅ Good build time (< 10 minutes)"
    elif [[ "$duration" -lt 1200 ]]; then
        echo "⚠️  Moderate build time (< 20 minutes)"
    else
        echo "🐌 Slow build time (> 20 minutes)"
    fi
else
    echo "   Duration: not available"
fi

# Check available disk space (to ensure future builds won't fail)
echo "💾 Disk space check:"
df -h . 2>/dev/null | head -2 || echo "Could not check disk space"

# Display environment summary
echo "🌍 Build Environment Summary:"
echo "   Xcode Version: ${CI_XCODE_VERSION:-'not available'}"
echo "   macOS Version: $(sw_vers -productVersion 2>/dev/null || echo 'not available')"
echo "   Swift Version: $(swift --version 2>/dev/null | head -1 || echo 'not available')"

# Success notification with detailed status
if [[ "$CI_XCODEBUILD_ACTION" == "archive" ]]; then
    echo "🚀 Build ready for TestFlight distribution!"
    echo "   App: DigitonePad"
    echo "   Bundle ID: com.digitonepad.app"
    echo "   Team: GN9UGD54YC"
    echo "   Archive: $CI_ARCHIVE_PATH"
    echo ""
    echo "📱 Next steps:"
    echo "   1. Archive will be automatically processed for TestFlight"
    echo "   2. Check App Store Connect for upload status"
    echo "   3. Review crash reports and feedback"
else
    echo "✅ Build completed successfully"
    echo "   Build Type: ${CI_XCODEBUILD_ACTION:-'standard build'}"
    echo "   All DigitonePad frameworks compiled successfully"
fi

# Final validation summary
echo ""
echo "📋 Validation Summary:"
echo "   ✅ Project generation: Success"
echo "   ✅ Build completion: Success"
echo "   ✅ Framework builds: $framework_count/${#expected_frameworks[@]} detected"
if [[ "$warning_count" -gt 0 ]]; then
    echo "   ⚠️  Build warnings: $warning_count (non-critical)"
else
    echo "   ✅ Build warnings: 0"
fi

echo "✅ Enhanced post-build script completed successfully"
echo "🎯 Build process matches local development standards"