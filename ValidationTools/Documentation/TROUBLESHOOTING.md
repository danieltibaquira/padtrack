# DigitonePad Validation Troubleshooting Guide

This guide helps resolve common issues encountered during validation testing.

## Quick Diagnostics

### 1. Check System Requirements
```bash
# Verify Xcode version
xcodebuild -version

# Verify Swift version
swift --version

# Check available simulators
xcrun simctl list devices available
```

### 2. Verify Project State
```bash
# Clean build
swift package clean
xcodebuild clean

# Reset package dependencies
swift package reset

# Rebuild everything
swift build
```

## Common Issues and Solutions

### Build Failures

#### Issue: Swift Package Build Fails
**Symptoms:**
- `swift build` command fails
- Compilation errors in modules
- Missing dependencies

**Solutions:**
1. **Clean and rebuild:**
   ```bash
   swift package clean
   swift package resolve
   swift build
   ```

2. **Check Package.swift syntax:**
   - Verify all dependencies are correctly specified
   - Check for typos in module names
   - Ensure version constraints are valid

3. **Verify module structure:**
   ```bash
   # Check that all source files are in correct locations
   find Sources -name "*.swift" | head -10
   ```

#### Issue: iOS Build Fails
**Symptoms:**
- `xcodebuild` command fails
- Simulator not found errors
- Code signing issues

**Solutions:**
1. **Check simulator availability:**
   ```bash
   xcrun simctl list devices available | grep iPad
   ```

2. **Install missing simulators:**
   - Open Xcode
   - Go to Xcode → Preferences → Components
   - Install required iOS simulators

3. **Use correct destination format:**
   ```bash
   # Correct format
   xcodebuild -destination 'platform=iOS Simulator,name=iPad Pro (11-inch) (4th generation),OS=17.2'
   ```

### Test Failures

#### Issue: DataLayer Tests Fail
**Symptoms:**
- `swift test --filter DataLayerTests` fails
- Core Data initialization errors
- Entity creation failures

**Solutions:**
1. **Check Core Data model:**
   ```bash
   # Verify model file exists
   ls -la Sources/DataLayer/Resources/DigitonePad.xcdatamodeld/
   ```

2. **Regenerate entity classes:**
   - Open DigitonePad.xcdatamodeld in Xcode
   - Select each entity
   - Set Codegen to "Category/Extension"
   - Clean and rebuild

3. **Check test database setup:**
   - Ensure tests use in-memory store
   - Verify test data cleanup between tests

#### Issue: Protocol Tests Fail
**Symptoms:**
- MachineProtocols tests fail
- Mock implementation errors
- Protocol compilation issues

**Solutions:**
1. **Verify protocol implementations:**
   ```bash
   # Check mock implementations exist
   ls -la Tests/MachineProtocolsTests/
   ```

2. **Check protocol conformance:**
   - Ensure all required methods are implemented
   - Verify property types match protocol definitions
   - Check for missing protocol methods

### Memory Issues

#### Issue: High Memory Usage
**Symptoms:**
- Memory usage exceeds recommended thresholds
- Memory warnings during testing
- Poor memory recovery after stress tests

**Solutions:**
1. **Analyze memory patterns:**
   - Use Instruments for detailed profiling
   - Check for retain cycles
   - Verify proper object deallocation

2. **Optimize memory usage:**
   ```swift
   // Use weak references to break retain cycles
   weak var delegate: SomeDelegate?
   
   // Implement lazy loading
   lazy var expensiveProperty = createExpensiveObject()
   
   // Use autoreleasepool for batch operations
   autoreleasepool {
       // Batch processing code
   }
   ```

3. **Monitor memory in tests:**
   - Add memory assertions to tests
   - Use memory profiling tools
   - Implement memory pressure handling

### Simulator Issues

#### Issue: Simulator Not Responding
**Symptoms:**
- Builds succeed but simulator doesn't launch
- Simulator crashes during testing
- Timeout errors

**Solutions:**
1. **Reset simulator:**
   ```bash
   # Reset specific simulator
   xcrun simctl erase "iPad Pro (11-inch) (4th generation)"
   
   # Reset all simulators
   xcrun simctl erase all
   ```

2. **Restart simulator service:**
   ```bash
   sudo killall -9 com.apple.CoreSimulator.CoreSimulatorService
   ```

3. **Check simulator logs:**
   ```bash
   # View simulator logs
   xcrun simctl spawn booted log show --predicate 'process == "DigitonePad"'
   ```

### Dependency Issues

#### Issue: Circular Dependencies
**Symptoms:**
- Build fails with circular dependency errors
- Module import conflicts
- Linker errors

**Solutions:**
1. **Analyze dependency graph:**
   ```bash
   swift package show-dependencies --format json
   ```

2. **Restructure dependencies:**
   - Move shared protocols to separate module
   - Use dependency injection instead of direct imports
   - Create protocol-only modules for shared interfaces

3. **Check Package.swift:**
   - Verify target dependencies are correct
   - Remove unnecessary dependencies
   - Use testTarget dependencies appropriately

## Performance Optimization

### Memory Optimization
1. **Use object pooling for frequently allocated objects**
2. **Implement lazy loading for Core Data relationships**
3. **Use weak references to break retain cycles**
4. **Monitor memory usage with Instruments**

### Build Optimization
1. **Use incremental builds during development**
2. **Optimize build settings for debug/release**
3. **Use build caching when possible**
4. **Minimize dependencies in Package.swift**

## Validation Script Issues

### Issue: Script Permissions
**Symptoms:**
- "Permission denied" errors
- Scripts won't execute

**Solution:**
```bash
# Make scripts executable
chmod +x ValidationTools/Scripts/*.sh
```

### Issue: Missing Dependencies
**Symptoms:**
- `bc` command not found
- `jq` command not found
- Python scripts fail

**Solutions:**
```bash
# Install missing tools (macOS)
brew install bc jq python3

# Verify installations
which bc jq python3
```

### Issue: Report Generation Fails
**Symptoms:**
- JSON parsing errors
- Report files not created
- Invalid JSON output

**Solutions:**
1. **Check JSON syntax:**
   ```bash
   # Validate JSON files
   jq . ValidationTools/Reports/latest_report.json
   ```

2. **Verify file permissions:**
   ```bash
   # Check report directory permissions
   ls -la ValidationTools/Reports/
   ```

3. **Clean up corrupted reports:**
   ```bash
   # Remove corrupted reports
   rm ValidationTools/Reports/*_corrupted_*.json
   ```

## Getting Additional Help

### Debug Information Collection
When reporting issues, include:

1. **System information:**
   ```bash
   sw_vers
   xcodebuild -version
   swift --version
   ```

2. **Project state:**
   ```bash
   swift package describe --type json
   git status
   ```

3. **Error logs:**
   - Build logs from `/tmp/`
   - Validation report files
   - Console output with full error messages

### Log Analysis
```bash
# View recent validation logs
ls -lt /tmp/*validation* | head -5

# Check system logs for crashes
log show --predicate 'process == "DigitonePad"' --last 1h
```

### Performance Profiling
```bash
# Profile memory usage
instruments -t "Allocations" -D trace_output.trace YourApp.app

# Profile CPU usage  
instruments -t "Time Profiler" -D cpu_trace.trace YourApp.app
```

## Prevention Best Practices

1. **Regular validation runs during development**
2. **Monitor memory usage continuously**
3. **Keep dependencies up to date**
4. **Use version control for validation reports**
5. **Document any custom validation modifications**
6. **Test on multiple device types regularly**
7. **Maintain clean build environments**

## Emergency Recovery

If validation completely fails:

1. **Reset to known good state:**
   ```bash
   git clean -fdx
   swift package reset
   swift package resolve
   ```

2. **Regenerate Xcode project:**
   ```bash
   xcodegen generate
   ```

3. **Clear all caches:**
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/DigitonePad-*
   rm -rf .build/
   ```

4. **Restart development tools:**
   - Quit Xcode completely
   - Restart Terminal
   - Clear simulator data

Remember: The validation framework is designed to be robust, but when in doubt, start with a clean environment and rebuild step by step.
