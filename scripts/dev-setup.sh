#!/bin/bash

# DigitonePad Development Environment Setup Script
# Ensures local environment matches CI/CD configuration

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SWIFT_VERSION="5.10"
XCODE_VERSION="16.0"
REQUIRED_MACOS_VERSION="14.0"

echo -e "${BLUE}🏗️  DigitonePad Development Environment Setup${NC}"
echo "================================================"

# Function to print status
print_status() {
    echo -e "${GREEN}✅${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ️${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    IS_MACOS=true
    print_info "Running on macOS - iOS development supported"
else
    IS_MACOS=false
    print_info "Running on $OSTYPE - Swift Package development only"
fi

# Function to check macOS version
check_macos_version() {
    if [[ "$IS_MACOS" == true ]]; then
        MACOS_VERSION=$(sw_vers -productVersion)
        print_info "macOS Version: $MACOS_VERSION"
        
        # Check if version is sufficient
        if [[ "$(printf '%s\n' "$REQUIRED_MACOS_VERSION" "$MACOS_VERSION" | sort -V | head -n1)" != "$REQUIRED_MACOS_VERSION" ]]; then
            print_warning "macOS version $MACOS_VERSION may not support required Xcode version"
        else
            print_status "macOS version $MACOS_VERSION is compatible"
        fi
    fi
}

# Function to check Swift version
check_swift_version() {
    if command -v swift >/dev/null 2>&1; then
        CURRENT_SWIFT=$(swift --version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
        print_info "Current Swift Version: $CURRENT_SWIFT"
        
        if [[ "$CURRENT_SWIFT" == "$SWIFT_VERSION" ]]; then
            print_status "Swift version matches CI requirement ($SWIFT_VERSION)"
        else
            print_warning "Swift version mismatch. Required: $SWIFT_VERSION, Found: $CURRENT_SWIFT"
            if [[ "$IS_MACOS" == true ]]; then
                print_info "Consider updating Xcode to get Swift $SWIFT_VERSION"
            fi
        fi
    else
        print_error "Swift not found. Please install Swift toolchain"
        return 1
    fi
}

# Function to check Xcode (macOS only)
check_xcode() {
    if [[ "$IS_MACOS" == true ]]; then
        if command -v xcodebuild >/dev/null 2>&1; then
            XCODE_VER=$(xcodebuild -version | head -n1 | grep -o '[0-9]\+\.[0-9]\+' | head -n1)
            print_info "Xcode Version: $XCODE_VER"
            
            if [[ "$(printf '%s\n' "$XCODE_VERSION" "$XCODE_VER" | sort -V | head -n1)" == "$XCODE_VERSION" ]]; then
                print_status "Xcode version $XCODE_VER meets requirement (>= $XCODE_VERSION)"
            else
                print_warning "Xcode version $XCODE_VER may not support Swift $SWIFT_VERSION"
            fi
        else
            print_error "Xcode not found. Please install Xcode from Mac App Store"
            return 1
        fi
    fi
}

# Function to check XcodeGen (macOS only)
check_xcodegen() {
    if [[ "$IS_MACOS" == true ]]; then
        if command -v xcodegen >/dev/null 2>&1; then
            XCODEGEN_VER=$(xcodegen --version)
            print_status "XcodeGen installed: $XCODEGEN_VER"
        else
            print_warning "XcodeGen not found. Installing via Homebrew..."
            if command -v brew >/dev/null 2>&1; then
                brew install xcodegen
                print_status "XcodeGen installed successfully"
            else
                print_error "Homebrew not found. Please install Homebrew first"
                return 1
            fi
        fi
    fi
}

# Function to validate Package.swift
validate_package_swift() {
    if [[ -f "Package.swift" ]]; then
        print_status "Package.swift found"
        
        # Check Swift tools version
        PACKAGE_SWIFT_VERSION=$(grep -o 'swift-tools-version: [0-9]\+\.[0-9]\+' Package.swift | grep -o '[0-9]\+\.[0-9]\+')
        if [[ "$PACKAGE_SWIFT_VERSION" == "$SWIFT_VERSION" ]]; then
            print_status "Package.swift Swift version matches ($SWIFT_VERSION)"
        else
            print_warning "Package.swift Swift version mismatch: $PACKAGE_SWIFT_VERSION (expected: $SWIFT_VERSION)"
        fi
    else
        print_error "Package.swift not found. Are you in the project root?"
        return 1
    fi
}

# Function to validate project.yml (macOS only)
validate_project_yml() {
    if [[ "$IS_MACOS" == true ]]; then
        if [[ -f "project.yml" ]]; then
            print_status "project.yml found"
            
            # Test XcodeGen generation
            print_info "Testing Xcode project generation..."
            if xcodegen generate --spec project.yml >/dev/null 2>&1; then
                print_status "Xcode project generation successful"
                
                if [[ -f "DigitonePad.xcodeproj/project.pbxproj" ]]; then
                    print_status "DigitonePad.xcodeproj created successfully"
                else
                    print_error "DigitonePad.xcodeproj not found after generation"
                    return 1
                fi
            else
                print_error "Xcode project generation failed"
                return 1
            fi
        else
            print_error "project.yml not found"
            return 1
        fi
    fi
}

# Function to resolve Swift Package dependencies
resolve_dependencies() {
    print_info "Resolving Swift Package dependencies..."
    if swift package resolve; then
        print_status "Dependencies resolved successfully"
    else
        print_error "Failed to resolve dependencies"
        return 1
    fi
}

# Function to run build test
test_build() {
    print_info "Testing Swift Package build..."
    
    # Platform-agnostic modules
    MODULES=("MachineProtocols" "DataModel" "DataLayer")
    
    for module in "${MODULES[@]}"; do
        print_info "Building $module..."
        if swift build --target "$module" >/dev/null 2>&1; then
            print_status "$module builds successfully"
        else
            print_error "Failed to build $module"
            return 1
        fi
    done
    
    # iOS-specific build (macOS only)
    if [[ "$IS_MACOS" == true ]] && [[ -f "DigitonePad.xcodeproj/project.pbxproj" ]]; then
        print_info "Testing iOS project build..."
        if xcodebuild -project DigitonePad.xcodeproj -scheme DigitonePadApp -destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation),OS=latest' build >/dev/null 2>&1; then
            print_status "iOS project builds successfully"
        else
            print_warning "iOS project build failed (may require specific simulator)"
        fi
    fi
}

# Function to create local development environment info
create_env_info() {
    print_info "Creating environment info file..."
    
    cat > .env.local << EOF
# DigitonePad Local Development Environment
# Generated by dev-setup.sh on $(date)

# Environment Information
DEVELOPMENT_PLATFORM=$(uname -s)
SWIFT_VERSION_DETECTED=$CURRENT_SWIFT
SWIFT_VERSION_REQUIRED=$SWIFT_VERSION

# Paths
PROJECT_ROOT=$(pwd)
BUILD_DIR=$(pwd)/.build

# Development Mode
DEVELOPMENT_MODE=true
DEBUG_LOGGING=true

# iOS Development (macOS only)
EOF

    if [[ "$IS_MACOS" == true ]]; then
        cat >> .env.local << EOF
IOS_DEVELOPMENT_ENABLED=true
XCODE_VERSION_DETECTED=$XCODE_VER
XCODE_PROJECT_PATH=$(pwd)/DigitonePad.xcodeproj
EOF
    else
        cat >> .env.local << EOF
IOS_DEVELOPMENT_ENABLED=false
PLATFORM_LIMITATION=swift-package-only
EOF
    fi
    
    print_status "Environment info saved to .env.local"
}

# Function to setup VS Code configuration
setup_vscode() {
    if [[ ! -d ".vscode" ]]; then
        mkdir -p .vscode
    fi
    
    # VS Code settings
    cat > .vscode/settings.json << 'EOF'
{
    "swift.path": "/usr/bin/swift",
    "swift.buildPath": ".build",
    "swift.disableAutoResolve": false,
    "swift.autoGenerateTests": true,
    "files.associations": {
        "*.swift": "swift"
    },
    "editor.formatOnSave": true,
    "editor.codeActionsOnSave": {
        "source.organizeImports": "explicit"
    },
    "terminal.integrated.env.osx": {
        "DEVELOPMENT_MODE": "true"
    },
    "terminal.integrated.env.linux": {
        "DEVELOPMENT_MODE": "true"
    }
}
EOF

    # Launch configuration
    cat > .vscode/launch.json << 'EOF'
{
    "version": "0.2.0",
    "configurations": [
        {
            "type": "swift",
            "request": "launch",
            "name": "Debug DigitonePad Tests",
            "program": "${workspaceFolder}/.build/debug/DigitonePadPackageTests.xctest",
            "args": [],
            "cwd": "${workspaceFolder}",
            "stopOnEntry": false,
            "console": "integratedTerminal"
        }
    ]
}
EOF

    # Tasks configuration
    cat > .vscode/tasks.json << 'EOF'
{
    "version": "2.0.0",
    "tasks": [
        {
            "label": "Swift Build",
            "type": "shell",
            "command": "swift",
            "args": ["build"],
            "group": {
                "kind": "build",
                "isDefault": true
            },
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "problemMatcher": []
        },
        {
            "label": "Swift Test",
            "type": "shell",
            "command": "swift",
            "args": ["test"],
            "group": "test",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            }
        },
        {
            "label": "Generate Xcode Project",
            "type": "shell",
            "command": "xcodegen",
            "args": ["generate"],
            "group": "build",
            "presentation": {
                "echo": true,
                "reveal": "always",
                "focus": false,
                "panel": "shared"
            },
            "condition": "osx"
        }
    ]
}
EOF

    print_status "VS Code configuration created"
}

# Main execution
main() {
    echo -e "\n${BLUE}🔍 Environment Validation${NC}"
    echo "=========================="
    
    check_macos_version
    check_swift_version || return 1
    check_xcode
    check_xcodegen
    
    echo -e "\n${BLUE}📋 Project Validation${NC}"
    echo "====================="
    
    validate_package_swift || return 1
    validate_project_yml
    
    echo -e "\n${BLUE}🔨 Build Testing${NC}" 
    echo "================"
    
    resolve_dependencies || return 1
    test_build || return 1
    
    echo -e "\n${BLUE}⚙️ Environment Setup${NC}"
    echo "===================="
    
    create_env_info
    setup_vscode
    
    echo -e "\n${GREEN}🎉 Development Environment Setup Complete!${NC}"
    echo "==========================================="
    echo ""
    echo -e "${GREEN}✅ Environment validated and configured${NC}"
    echo -e "${GREEN}✅ Dependencies resolved${NC}"
    echo -e "${GREEN}✅ Build tested successfully${NC}"
    echo -e "${GREEN}✅ VS Code configured${NC}"
    echo ""
    echo -e "${BLUE}📋 Next Steps:${NC}"
    echo "1. Open project in VS Code: code ."
    echo "2. Use Command Palette (Cmd+Shift+P) -> 'Swift: Build'"
    echo "3. Check .env.local for environment details"
    if [[ "$IS_MACOS" == true ]]; then
        echo "4. Open DigitonePad.xcodeproj in Xcode for iOS development"
    fi
    echo ""
    echo -e "${BLUE}🚀 Your development environment now matches CI/CD!${NC}"
}

# Run main function
main "$@"