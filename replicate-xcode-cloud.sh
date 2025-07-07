#!/bin/bash

# Xcode Cloud Local Replication Script
# Simulates the exact environment and build process used by Xcode Cloud
# to catch CI failures before pushing commits

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DERIVED_DATA_PATH="$HOME/Library/Developer/Xcode/DerivedData"
PROJECT_NAME="DigitonePad"
SCHEME_NAME="DigitonePad"

# Flags
CLEAN_ONLY=false
QUICK_MODE=false
FULL_MODE=false
SETUP_HOOKS=false
COMPARE_ONLY=false
VERBOSE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Replicates Xcode Cloud build environment locally to catch CI failures before pushing."
    echo ""
    echo "OPTIONS:"
    echo "  --clean       Perform only clean build simulation (no validation)"
    echo "  --quick       Quick validation mode (essential checks only)"
    echo "  --full        Full validation mode (comprehensive testing)"
    echo "  --compare     Compare project.yml vs generated .xcodeproj only"
    echo "  --setup-hooks Setup pre-commit validation hooks"
    echo "  --verbose     Enable verbose output"
    echo "  --help        Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  $0 --quick                    # Quick pre-commit validation"
    echo "  $0 --full                     # Comprehensive validation"
    echo "  $0 --clean                    # Clean build only"
    echo "  $0 --setup-hooks              # Setup automatic validation"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --clean)
            CLEAN_ONLY=true
            shift
            ;;
        --quick)
            QUICK_MODE=true
            shift
            ;;
        --full)
            FULL_MODE=true
            shift
            ;;
        --compare)
            COMPARE_ONLY=true
            shift
            ;;
        --setup-hooks)
            SETUP_HOOKS=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Unknown option: $1${NC}"
            show_usage
            exit 1
            ;;
    esac
done

# Set default mode if none specified
if [[ "$CLEAN_ONLY" == false && "$QUICK_MODE" == false && "$FULL_MODE" == false && "$COMPARE_ONLY" == false && "$SETUP_HOOKS" == false ]]; then
    QUICK_MODE=true
fi

# Verbose logging function
log_verbose() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}📝 $1${NC}"
    fi
}

# Error tracking
ERRORS_FOUND=0
ERROR_LOG=""

report_error() {
    echo -e "${RED}❌ ERROR: $1${NC}"
    ERROR_LOG="$ERROR_LOG\n❌ $1"
    ((ERRORS_FOUND++))
}

report_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

report_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

report_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Main header
echo -e "${PURPLE}🚀 Xcode Cloud Local Replication${NC}"
echo "========================================"
echo -e "${BLUE}Project: $PROJECT_NAME${NC}"
echo -e "${BLUE}Working Directory: $PROJECT_ROOT${NC}"
echo ""

cd "$PROJECT_ROOT"

# Setup pre-commit hooks
setup_pre_commit_hooks() {
    echo -e "\n${BLUE}🔧 Setting up pre-commit validation hooks...${NC}"
    
    if [[ ! -d ".git" ]]; then
        report_error "Not a git repository"
        return 1
    fi
    
    # Create pre-commit hook
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Auto-generated pre-commit hook for Xcode Cloud replication

echo "🔍 Running pre-commit validation..."

# Run quick validation
if ./replicate-xcode-cloud.sh --quick; then
    echo "✅ Pre-commit validation passed"
    exit 0
else
    echo "❌ Pre-commit validation failed"
    echo "Fix issues before committing or use 'git commit --no-verify' to bypass"
    exit 1
fi
EOF
    
    chmod +x .git/hooks/pre-commit
    report_success "Pre-commit hook installed"
    
    # Create pre-push hook  
    cat > .git/hooks/pre-push << 'EOF'
#!/bin/bash
# Auto-generated pre-push hook for Xcode Cloud replication

echo "🔍 Running pre-push validation..."

# Run full validation before push
if ./replicate-xcode-cloud.sh --full; then
    echo "✅ Pre-push validation passed"
    exit 0
else
    echo "❌ Pre-push validation failed"
    echo "Fix issues before pushing or use 'git push --no-verify' to bypass"
    exit 1
fi
EOF
    
    chmod +x .git/hooks/pre-push
    report_success "Pre-push hook installed"
    
    echo ""
    echo -e "${GREEN}🎉 Pre-commit hooks successfully installed!${NC}"
    echo ""
    echo "Hooks installed:"
    echo "  • pre-commit: Runs quick validation before each commit"
    echo "  • pre-push: Runs full validation before each push"
    echo ""
    echo "To bypass hooks temporarily:"
    echo "  git commit --no-verify"
    echo "  git push --no-verify"
}

if [[ "$SETUP_HOOKS" == true ]]; then
    setup_pre_commit_hooks
    exit 0
fi

# Project comparison function
compare_project_configuration() {
    echo -e "\n${BLUE}📊 Comparing project.yml vs generated .xcodeproj...${NC}"
    
    if [[ ! -f "project.yml" ]]; then
        report_error "project.yml not found"
        return 1
    fi
    
    # Backup existing project if it exists
    if [[ -d "${PROJECT_NAME}.xcodeproj" ]]; then
        log_verbose "Backing up existing .xcodeproj"
        mv "${PROJECT_NAME}.xcodeproj" "${PROJECT_NAME}.xcodeproj.backup"
    fi
    
    # Generate fresh project
    log_verbose "Generating fresh project from project.yml"
    if xcodegen generate; then
        report_success "Project generated successfully from project.yml"
    else
        report_error "Failed to generate project from project.yml"
        return 1
    fi
    
    # Compare with backup if it exists
    if [[ -d "${PROJECT_NAME}.xcodeproj.backup" ]]; then
        log_verbose "Comparing project configurations"
        
        # Compare build settings
        if diff -r "${PROJECT_NAME}.xcodeproj.backup/project.pbxproj" "${PROJECT_NAME}.xcodeproj/project.pbxproj" > /dev/null; then
            report_success "Project configurations match"
        else
            report_warning "Project configurations differ (this may be expected)"
        fi
        
        # Restore backup
        rm -rf "${PROJECT_NAME}.xcodeproj"
        mv "${PROJECT_NAME}.xcodeproj.backup" "${PROJECT_NAME}.xcodeproj"
    fi
}

if [[ "$COMPARE_ONLY" == true ]]; then
    compare_project_configuration
    exit 0
fi

# Clean build simulation function
simulate_clean_build() {
    echo -e "\n${BLUE}🧹 Simulating Xcode Cloud clean build environment...${NC}"
    
    # Step 1: Remove all derived data (like Xcode Cloud)
    echo "1. Removing derived data..."
    if [[ -d "$DERIVED_DATA_PATH" ]]; then
        log_verbose "Clearing derived data at $DERIVED_DATA_PATH"
        rm -rf "$DERIVED_DATA_PATH"/*
        report_success "Derived data cleared"
    else
        report_info "No derived data found"
    fi
    
    # Step 2: Remove existing project (like Xcode Cloud regeneration)
    echo "2. Removing existing .xcodeproj..."
    if [[ -d "${PROJECT_NAME}.xcodeproj" ]]; then
        log_verbose "Removing ${PROJECT_NAME}.xcodeproj"
        rm -rf "${PROJECT_NAME}.xcodeproj"
        report_success "Existing project removed"
    fi
    
    # Step 3: Install dependencies (simulate Xcode Cloud environment)
    echo "3. Installing build dependencies..."
    if command -v xcodegen &> /dev/null; then
        report_success "xcodegen found"
    else
        report_error "xcodegen not installed (required for project generation)"
        return 1
    fi
    
    # Step 4: Generate project from project.yml (like Xcode Cloud)
    echo "4. Generating project from project.yml..."
    log_verbose "Running: xcodegen generate"
    if xcodegen generate; then
        report_success "Project generated from project.yml"
    else
        report_error "Failed to generate project from project.yml"
        return 1
    fi
    
    # Step 5: Verify project structure
    echo "5. Verifying project structure..."
    if [[ -d "${PROJECT_NAME}.xcodeproj" ]]; then
        report_success "Project structure verified"
    else
        report_error "Project not found after generation"
        return 1
    fi
    
    # Step 6: Check scheme availability
    echo "6. Checking build schemes..."
    log_verbose "Listing available schemes"
    if xcodebuild -list -project "${PROJECT_NAME}.xcodeproj" | grep -q "$SCHEME_NAME"; then
        report_success "Build scheme '$SCHEME_NAME' found"
    else
        report_error "Build scheme '$SCHEME_NAME' not found"
        xcodebuild -list -project "${PROJECT_NAME}.xcodeproj"
        return 1
    fi
    
    # Step 7: Attempt clean build (like Xcode Cloud)
    echo "7. Performing clean build..."
    log_verbose "Building for iOS Simulator (matching Xcode Cloud)"
    
    local build_output
    local build_success=true
    
    # Capture build output
    if build_output=$(xcodebuild \
        -project "${PROJECT_NAME}.xcodeproj" \
        -scheme "$SCHEME_NAME" \
        -destination "generic/platform=iOS Simulator" \
        -configuration Debug \
        clean build 2>&1); then
        report_success "Clean build completed successfully"
    else
        build_success=false
        report_error "Clean build failed"
    fi
    
    # Analyze build output
    if [[ "$build_success" == false ]]; then
        echo ""
        echo -e "${RED}📋 BUILD FAILURE ANALYSIS:${NC}"
        echo "----------------------------------------"
        
        # Extract key error information
        echo "$build_output" | grep -E "(error:|warning:|❌)" | head -10
        
        echo ""
        echo -e "${YELLOW}💡 Common solutions:${NC}"
        echo "  • Check import statements for missing modules"
        echo "  • Verify Core Data entity names match actual classes"
        echo "  • Ensure all dependencies are properly declared in project.yml"
        echo "  • Check for Swift version compatibility issues"
        
        # Save full build log
        echo "$build_output" > "xcode-cloud-replication-build.log"
        echo -e "${BLUE}📄 Full build log saved to: xcode-cloud-replication-build.log${NC}"
        
        return 1
    fi
    
    return 0
}

# Core Data validation function
validate_core_data() {
    echo -e "\n${BLUE}🗄️  Validating Core Data configuration...${NC}"
    
    # Check for Core Data model file
    if find . -name "*.xcdatamodeld" -type d | head -1 | grep -q ".xcdatamodeld"; then
        local model_file=$(find . -name "*.xcdatamodeld" -type d | head -1)
        report_success "Core Data model found: $(basename "$model_file")"
        
        # Check for generated classes
        if find Sources -name "*+CoreDataClass.swift" | head -1 | grep -q "CoreDataClass"; then
            report_success "Core Data classes found"
        else
            report_warning "No Core Data classes found (may be auto-generated)"
        fi
        
        # Check for entity imports
        local entity_errors=0
        while read -r swift_file; do
            if grep -q "PresetEntity\|AudioEngine[^M]\|CoreDataStack" "$swift_file"; then
                report_error "Incorrect entity references in $(basename "$swift_file")"
                ((entity_errors++))
            fi
        done < <(find Sources -name "*.swift")
        
        if [[ $entity_errors -eq 0 ]]; then
            report_success "Core Data entity references validated"
        fi
    else
        report_warning "No Core Data model found"
    fi
}

# Module validation function
validate_modules() {
    echo -e "\n${BLUE}📦 Validating module structure...${NC}"
    
    local expected_modules=(
        "MachineProtocols"
        "DataModel" 
        "DataLayer"
        "AudioEngine"
        "SequencerModule"
        "VoiceModule"
        "FilterModule"
        "FilterMachine"
        "FXModule"
        "MIDIModule"
        "UIComponents"
        "AppShell"
    )
    
    local missing_modules=0
    for module in "${expected_modules[@]}"; do
        if [[ -d "Sources/$module" ]]; then
            report_success "Module found: $module"
        else
            report_error "Module missing: $module"
            ((missing_modules++))
        fi
    done
    
    if [[ $missing_modules -eq 0 ]]; then
        report_success "All expected modules found"
    fi
}

# Quick validation function
run_quick_validation() {
    echo -e "\n${BLUE}⚡ Running quick validation...${NC}"
    
    # Check critical files
    if [[ -f "project.yml" ]]; then
        report_success "project.yml found"
    else
        report_error "project.yml missing"
    fi
    
    # Run existing syntax validation
    if [[ -f "quick_syntax_check.sh" ]]; then
        if ./quick_syntax_check.sh; then
            report_success "Syntax validation passed"
        else
            report_error "Syntax validation failed"
        fi
    fi
    
    # Run API validation
    if [[ -f "ci_scripts/ci_api_validation.sh" ]]; then
        if ./ci_scripts/ci_api_validation.sh; then
            report_success "API validation passed"
        else
            report_error "API validation failed"
        fi
    fi
}

# Full validation function
run_full_validation() {
    echo -e "\n${BLUE}🔍 Running comprehensive validation...${NC}"
    
    run_quick_validation
    validate_modules
    validate_core_data
    compare_project_configuration
    simulate_clean_build
}

# Main execution
echo -e "${BLUE}🎯 Mode: $(if [[ "$CLEAN_ONLY" == true ]]; then echo "Clean Build Only"; elif [[ "$QUICK_MODE" == true ]]; then echo "Quick Validation"; elif [[ "$FULL_MODE" == true ]]; then echo "Full Validation"; fi)${NC}"
echo ""

if [[ "$CLEAN_ONLY" == true ]]; then
    simulate_clean_build
elif [[ "$QUICK_MODE" == true ]]; then
    run_quick_validation
elif [[ "$FULL_MODE" == true ]]; then
    run_full_validation
fi

# Final summary
echo ""
echo "========================================"
if [[ $ERRORS_FOUND -eq 0 ]]; then
    echo -e "${GREEN}🎉 VALIDATION PASSED!${NC}"
    echo -e "${GREEN}✅ No issues found - safe to commit/push${NC}"
    echo ""
    echo -e "${BLUE}📊 Summary:${NC}"
    echo "  • Environment matches Xcode Cloud expectations"
    echo "  • All validations passed"
    echo "  • Ready for CI/CD pipeline"
    exit 0
else
    echo -e "${RED}❌ VALIDATION FAILED!${NC}"
    echo -e "${RED}Found $ERRORS_FOUND issue(s) that would cause CI failures${NC}"
    echo ""
    echo -e "${YELLOW}📋 Issues found:${NC}"
    echo -e "$ERROR_LOG"
    echo ""
    echo -e "${BLUE}💡 Next steps:${NC}"
    echo "  1. Fix the reported issues"
    echo "  2. Run this script again to verify fixes"
    echo "  3. Use --verbose flag for detailed debugging"
    echo ""
    echo -e "${BLUE}🔧 For help with specific issues:${NC}"
    echo "  • Check the generated build log: xcode-cloud-replication-build.log"
    echo "  • Compare local vs CI environments with --compare"
    echo "  • Use --clean to test clean build behavior"
    exit 1
fi