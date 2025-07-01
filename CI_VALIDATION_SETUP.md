# CI Validation Setup and Usage Guide

## Overview

This document describes the comprehensive pre-commit validation system designed to catch CI failures before pushing to GitHub. The system validates code compatibility, build status, and common issues that cause CI failures.

## Quick Start

### Running Pre-Commit Validation

```bash
# Make script executable (one time)
chmod +x pre_commit_validation.sh

# Run validation before pushing
./pre_commit_validation.sh
```

### Expected Output

```
╔══════════════════════════════════════════════════════════════════════════════╗
║                          PadTrack Pre-Commit Validation                     ║
║                    Preventing CI Failures Before Push                       ║
╚══════════════════════════════════════════════════════════════════════════════╝

[STEP] Checking Swift version compatibility...
✅ Swift version compatibility: OK

[STEP] Checking for Swift 6.0 incompatible syntax...
✅ No Swift 6.0 incompatible syntax found

[STEP] Validating Package.swift syntax...
✅ Package.swift syntax: Valid

[STEP] Testing Swift Package build...
✅ Swift Package build: Successful

🎉 All validation tests passed! Ready to push to GitHub.
```

## Validation Tests

### 1. Swift Version Compatibility
- **Purpose**: Ensures local Swift version is compatible with Package.swift requirements
- **Checks**: Compares local Swift version against `swift-tools-version`
- **Fixes**: Update Package.swift or install compatible Swift version

### 2. Swift 6.0 Incompatible Syntax
- **Purpose**: Detects syntax that doesn't work with Swift 5.10 (CI environment)
- **Checks**: 
  - `@preconcurrency` attributes
  - `consuming` parameters
  - `borrowing` parameters
- **Fixes**: Remove or replace incompatible syntax

### 3. Package.swift Validation
- **Purpose**: Ensures Package.swift has valid syntax
- **Checks**: Runs `swift package dump-package`
- **Fixes**: Fix syntax errors in Package.swift

### 4. Unhandled Files Check
- **Purpose**: Identifies files that will cause build warnings
- **Checks**: Looks for unhandled `.md`, `.txt`, `.json`, `.sh` files
- **Fixes**: Add `exclude` clauses to Package.swift targets

### 5. Swift Package Build
- **Purpose**: Verifies the package builds successfully
- **Checks**: Runs `swift build`
- **Fixes**: Address compilation errors

### 6. Swift Package Tests
- **Purpose**: Ensures all tests pass
- **Checks**: Runs `swift test`
- **Fixes**: Fix failing tests

### 7. Print Statement Detection
- **Purpose**: Finds print statements that violate SwiftLint rules
- **Checks**: Searches for `print(` in source files
- **Fixes**: Replace with proper logging or comments

### 8. Dependency Resolution
- **Purpose**: Verifies all dependencies can be resolved
- **Checks**: Runs `swift package resolve`
- **Fixes**: Update Package.swift dependencies

### 9. Deprecated API Scan
- **Purpose**: Identifies deprecated APIs that cause warnings
- **Checks**: Searches for known deprecated patterns
- **Fixes**: Update to modern APIs

### 10. Git Status Check
- **Purpose**: Ensures changes are staged for commit
- **Checks**: Verifies staged changes exist
- **Information**: Shows what files will be committed

## Fixed Issues

### Swift 6.0 Compatibility Issues

1. **@preconcurrency Syntax Removed**
   - `Sources/AudioEngine/AudioEngine.swift`
   - `Sources/MIDIModule/MIDIPresenter.swift`
   - `Sources/MIDIModule/MIDIViewController.swift`
   - `Sources/MIDIModule/MIDIViewModel.swift`
   - `Sources/MIDIModule/MIDIModuleProtocols.swift`
   - `Tests/DataLayerTests/CoreDataTestBase.swift`

2. **Package.swift Unhandled Files**
   - Added `exclude` clauses for documentation files
   - Added `exclude` clauses for test utility files
   - Properly handled `.md`, `.docc`, and other resource files

3. **Deprecated API Updates**
   - Updated `NSKeyedUnarchiver.unarchiveTopLevelObjectWithData` to `unarchivedObject(ofClass:from:)`
   - Fixed variable mutation warnings (`var` → `let`)

## Integration with Development Workflow

### Before Each Commit

1. **Stage your changes**:
   ```bash
   git add .
   ```

2. **Run validation**:
   ```bash
   ./pre_commit_validation.sh
   ```

3. **Fix any issues** identified by the validation

4. **Re-run validation** until all tests pass

5. **Commit and push**:
   ```bash
   git commit -m "Your commit message"
   git push origin your-branch
   ```

### Continuous Integration Benefits

With this validation system:
- ✅ **No more Swift version incompatibilities**
- ✅ **No more unhandled file warnings**
- ✅ **No more build failures due to syntax errors**
- ✅ **No more test failures in CI**
- ✅ **Faster CI feedback loop**

## Common Issues and Solutions

### Issue: Swift CLI Not Found
```bash
[ERROR] Swift CLI not found
```
**Solution**: Install Xcode Command Line Tools or Swift toolchain

### Issue: @preconcurrency Syntax Errors
```bash
[ERROR] Found Swift 6.0 incompatible syntax: @preconcurrency
```
**Solution**: Remove `@preconcurrency` attributes from protocols and imports

### Issue: Unhandled Files
```bash
[WARNING] 4 unhandled file types found (will cause build warnings)
```
**Solution**: Add `exclude: ["filename.md"]` to affected targets in Package.swift

### Issue: Build Failures
```bash
[ERROR] Swift Package build: Failed
```
**Solution**: Check build log for specific compilation errors and fix them

### Issue: Test Failures
```bash
[ERROR] Swift Package tests: Failed
```
**Solution**: Run tests locally and fix failing test cases

## Validation Log

The script creates a detailed log at `/tmp/padtrack_validation_TIMESTAMP.log` containing:
- Full output from all validation steps
- Detailed error messages
- Build and test outputs
- Recommendations for fixes

## Future Enhancements

Potential additions to the validation system:
- SwiftLint integration (when available)
- Performance benchmarking
- Code coverage validation
- Security scanning
- Documentation validation

## Troubleshooting

If the validation script fails to run:

1. **Check permissions**:
   ```bash
   chmod +x pre_commit_validation.sh
   ```

2. **Check Swift installation**:
   ```bash
   swift --version
   ```

3. **Check file paths**:
   Ensure you're running from the project root directory

4. **Check dependencies**:
   Ensure all required tools are installed (Swift, Git)

## Summary

This validation system provides a comprehensive safety net to prevent CI failures by catching common issues before they reach the CI environment. By running this validation before each push, developers can ensure their changes will build and test successfully in the CI pipeline, leading to faster development cycles and more reliable builds.