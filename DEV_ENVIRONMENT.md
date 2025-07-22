# 🏗️ DigitonePad Development Environment Setup

Complete guide to replicate remote CI/CD environments locally and ensure build consistency.

## 🎯 **Problem Statement**

**Issue**: GitHub Actions compilation fails while local builds succeed  
**Root Cause**: Environment discrepancies between local development and CI/CD  
**Solution**: Standardized development environment with CI/CD parity validation  

---

## 🚀 **Quick Setup (Recommended)**

### 1. **Automated Setup**
```bash
# Make setup script executable
chmod +x scripts/dev-setup.sh

# Run comprehensive environment setup
./scripts/dev-setup.sh
```

### 2. **Validate Environment Parity**
```bash
# Make validation script executable  
chmod +x scripts/env-validate.sh

# Check local environment matches CI/CD
./scripts/env-validate.sh
```

### 3. **Docker Development Environment**
```bash
# Start development containers
docker-compose -f docker-compose.dev.yml up -d swift-dev

# Enter development container
docker-compose -f docker-compose.dev.yml exec swift-dev bash

# Run platform-agnostic tests
docker-compose -f docker-compose.dev.yml up test-runner
```

---

## 📋 **Environment Requirements**

### **CI/CD Configuration (Target Environment)**
- **Swift Version**: 5.10
- **Xcode Version**: 16.0+ (macOS)
- **macOS Version**: 14.0+ (for iOS development)
- **Required Tools**: XcodeGen, SwiftLint

### **Platform Support**
- **macOS**: Full iOS development + Swift Package development
- **Linux**: Swift Package development only (CI simulation)
- **Docker**: Containerized development environment

---

## 🔧 **Manual Setup Instructions**

### **macOS (Full iOS Development)**

#### 1. **Install Required Tools**
```bash
# Install Homebrew (if not installed)
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install Xcode from Mac App Store (version 16.0+)
# This provides Swift 5.10

# Install development tools
brew install xcodegen swiftlint
```

#### 2. **Validate Installation**
```bash
# Check versions match CI requirements
swift --version          # Should show Swift 5.10
xcodebuild -version      # Should show Xcode 16.0+
xcodegen --version       # Should show XcodeGen installed
swiftlint version        # Should show SwiftLint installed
```

#### 3. **Generate Xcode Project**
```bash
# Generate Xcode project file (required for iOS builds)
xcodegen generate

# Verify project was created
ls -la DigitonePad.xcodeproj/
```

#### 4. **Build Validation**
```bash
# Test Swift Package build (platform-agnostic)
swift package resolve
swift build --target MachineProtocols
swift build --target DataModel
swift build --target DataLayer

# Test iOS project build
xcodebuild -project DigitonePad.xcodeproj \
           -scheme DigitonePadApp \
           -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' \
           build
```

### **Linux/Docker (Swift Package Only)**

#### 1. **Docker Setup**
```bash
# Build development image
docker build -f Dockerfile.dev -t digitonepad-dev .

# Run development container
docker run -it --rm -v $(pwd):/workspace digitonepad-dev

# Or use docker-compose
docker-compose -f docker-compose.dev.yml up -d swift-dev
```

#### 2. **Container Development**
```bash
# Enter container
docker-compose exec swift-dev bash

# Inside container - run platform-agnostic builds
swift build --target MachineProtocols
swift build --target DataModel
swift build --target DataLayer

# Run platform-agnostic tests
swift test --filter MachineProtocolsTests
```

---

## 🧪 **Testing Environment Parity**

### **Validation Script Usage**
```bash
# Run comprehensive environment validation
./scripts/env-validate.sh

# Expected output for perfect parity:
# ✅ EXCELLENT: Environment fully matches CI/CD
# Pass Rate: 100%
```

### **Common Validation Failures & Solutions**

| Issue | Solution |
|-------|----------|
| `Swift version mismatch` | Update Xcode to 16.0+ |
| `XcodeGen not found` | `brew install xcodegen` |
| `DigitonePad.xcodeproj missing` | Run `xcodegen generate` |
| `Package resolution fails` | Check network and dependencies |
| `Build failures` | Validate Package.swift and sources |

### **CI/CD Simulation**
```bash
# Simulate exact CI/CD build process locally
./scripts/ci-simulation.sh
```

---

## 🏗️ **CI/CD Pipeline Overview**

### **Updated GitHub Actions Workflow**
The updated `.github/workflows/ci.yml` includes:

#### **Multi-Platform Strategy**
- **Linux Job**: Swift 5.10 container, platform-agnostic modules only
- **macOS Job**: Xcode 16.0, full iOS development and testing
- **Validation Jobs**: Code quality, security, project structure

#### **Key Improvements**
1. **Version Consistency**: Enforced Swift 5.10 and Xcode 16.0
2. **Error Handling**: Proper validation of Xcode project generation  
3. **Build Separation**: Platform-specific builds isolated
4. **Comprehensive Reporting**: Detailed status for each build stage

#### **Build Process**
```yaml
# Platform-agnostic (Linux)
swift build --target MachineProtocols
swift build --target DataModel
swift build --target DataLayer

# iOS-specific (macOS)
xcodegen generate
xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePadApp build
```

---

## 📁 **Project Structure**

### **Development Environment Files**
```
DigitonePad/
├── .github/workflows/ci.yml          # Updated CI/CD pipeline
├── Dockerfile.dev                    # Development container
├── docker-compose.dev.yml            # Multi-service development
├── scripts/
│   ├── dev-setup.sh                  # Automated environment setup
│   ├── env-validate.sh               # Environment parity validation
│   └── ci-simulation.sh              # Local CI simulation
├── .vscode/                          # VS Code configuration
│   ├── settings.json                 # Swift development settings
│   ├── launch.json                   # Debug configuration
│   └── tasks.json                    # Build tasks
├── .env.local                        # Local environment variables
└── DEV_ENVIRONMENT.md               # This documentation
```

### **Generated Files**
```
# Generated by setup scripts (gitignored)
.env.local                           # Local environment info
DigitonePad.xcodeproj/              # Generated Xcode project
.build/                             # Swift build artifacts
.swiftpm/                           # Package manager cache
```

---

## 🎛️ **VS Code Integration**

### **Automatic Configuration**
Running `./scripts/dev-setup.sh` automatically creates:

- **Swift Language Support**: Proper Swift path and build settings
- **Debug Configuration**: Swift test debugging  
- **Build Tasks**: One-click Swift builds and Xcode project generation
- **Format on Save**: Consistent code formatting

### **Recommended Extensions**
```bash
# Install VS Code Swift extension
code --install-extension swift-server.swift
```

### **Usage**
- **Build**: `Cmd+Shift+P` → "Tasks: Run Task" → "Swift Build"
- **Test**: `Cmd+Shift+P` → "Tasks: Run Task" → "Swift Test" 
- **Debug**: F5 to start debugging Swift tests
- **Generate Xcode**: `Cmd+Shift+P` → "Tasks: Run Task" → "Generate Xcode Project"

---

## 🐛 **Troubleshooting Common Issues**

### **"DigitonePad.xcodeproj does not exist" in CI**
**Cause**: Xcode project generation failing silently in CI  
**Solution**: Updated CI with proper error handling and validation
```bash
# Local test
xcodegen generate
ls -la DigitonePad.xcodeproj/project.pbxproj
```

### **Swift Version Mismatch**
**Cause**: Local Swift 5.9 vs CI Swift 5.10 requirement  
**Solution**: Update Xcode to 16.0+ which includes Swift 5.10
```bash
# Check current version
swift --version

# Expected output:
# Swift version 5.10.x
```

### **iOS Build Fails Locally But CI Expects It**
**Cause**: Missing iOS simulator or Xcode configuration  
**Solution**: Install required simulator and validate Xcode setup
```bash
# List available simulators
xcrun simctl list devices

# Install iPad Pro simulator if missing
# Xcode → Window → Devices and Simulators → Simulators → Add
```

### **Tests Fail in CI But Pass Locally**
**Cause**: Platform-specific test dependencies  
**Solution**: Use test filters for platform-agnostic testing
```bash
# Run platform-agnostic tests only
swift test --filter MachineProtocolsTests
```

### **Docker Build Issues**
**Cause**: Network restrictions or base image problems  
**Solution**: Use alternative base image or proxy configuration
```bash
# Debug container build
docker build -f Dockerfile.dev --no-cache --progress=plain -t digitonepad-dev .
```

---

## 🎯 **Best Practices**

### **Local Development Workflow**
1. **Environment Validation**: Run `./scripts/env-validate.sh` weekly
2. **Pre-Push Validation**: Test platform-agnostic builds before pushing  
3. **Xcode Project Sync**: Regenerate project after Package.swift changes
4. **CI Simulation**: Use Docker environment for Linux compatibility testing

### **Team Collaboration**
1. **Standardized Environment**: All developers run `./scripts/dev-setup.sh`
2. **Version Consistency**: Document and enforce tool versions
3. **Container Usage**: Use Docker for consistent cross-platform development
4. **Documentation Updates**: Update this guide when environment changes

### **CI/CD Optimization**
1. **Caching**: Package dependencies and build artifacts cached
2. **Parallel Execution**: Platform builds run simultaneously
3. **Early Failure**: Critical validations fail fast
4. **Comprehensive Reporting**: Clear status for each build stage

---

## 📞 **Support & Resources**

### **Quick Commands Reference**
```bash
# Complete environment setup
./scripts/dev-setup.sh

# Validate environment parity  
./scripts/env-validate.sh

# Docker development
docker-compose -f docker-compose.dev.yml up swift-dev

# Swift package build (CI simulation)
swift build --target MachineProtocols --target DataModel --target DataLayer

# iOS project build (macOS only)
xcodegen generate && xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePadApp build
```

### **Documentation**
- **Project Status**: `working_code.md` - Comprehensive project status
- **Build Infrastructure**: `BUILD_STATUS.md` - Build system documentation  
- **Package Configuration**: `Package.swift` - Swift Package Manager setup
- **Xcode Configuration**: `project.yml` - XcodeGen project definition

### **Getting Help**
- **Environment Issues**: Run `./scripts/env-validate.sh` and share output
- **CI/CD Problems**: Check GitHub Actions logs and compare with local validation
- **Build Failures**: Use Docker environment to replicate CI conditions

---

**🎉 Success Criteria**: Your local environment validation shows `✅ EXCELLENT: Environment fully matches CI/CD` and all builds pass consistently between local and CI/CD environments.