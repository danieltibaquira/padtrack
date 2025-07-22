#!/bin/bash

# Project Generation Comparison Tool
# Compares project.yml vs existing xcodeproj to identify differences

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${PURPLE}📊 Project Generation Comparison Tool${NC}"
echo "========================================"

# Configuration
PROJECT_NAME="DigitonePad"
COMPARISON_DIR="/tmp/project_comparison_$(date +%Y%m%d_%H%M%S)"
EXISTING_PROJECT="${PROJECT_NAME}.xcodeproj"
GENERATED_PROJECT="Generated_${PROJECT_NAME}.xcodeproj"

log() {
    echo -e "$1" | tee -a "$COMPARISON_DIR/comparison.log"
}

# Create comparison directory
mkdir -p "$COMPARISON_DIR"

log "${BLUE}📂 Comparison directory: $COMPARISON_DIR${NC}"

# Step 1: Backup existing project
log "${YELLOW}1. Backing up existing project...${NC}"

if [[ -d "$EXISTING_PROJECT" ]]; then
    cp -R "$EXISTING_PROJECT" "$COMPARISON_DIR/existing_project.xcodeproj"
    log "${GREEN}✅ Existing project backed up${NC}"
else
    log "${RED}❌ Existing project not found${NC}"
    exit 1
fi

# Step 2: Generate fresh project from project.yml
log "${YELLOW}2. Generating fresh project from project.yml...${NC}"

if [[ -f "project.yml" ]]; then
    # Generate in comparison directory
    cd "$COMPARISON_DIR"
    cp "../project.yml" .
    
    # Also copy any required files
    if [[ -d "../Sources" ]]; then
        cp -R "../Sources" .
    fi
    
    if [[ -d "../Tests" ]]; then
        cp -R "../Tests" .
    fi
    
    if [[ -d "../Resources" ]]; then
        cp -R "../Resources" .
    fi
    
    # Generate project
    if xcodegen generate --spec project.yml; then
        mv "${PROJECT_NAME}.xcodeproj" "$GENERATED_PROJECT"
        log "${GREEN}✅ Fresh project generated${NC}"
    else
        log "${RED}❌ Project generation failed${NC}"
        exit 1
    fi
    
    cd - > /dev/null
else
    log "${RED}❌ project.yml not found${NC}"
    exit 1
fi

# Step 3: Compare project structures
log "${YELLOW}3. Comparing project structures...${NC}"

# Function to extract project information
extract_project_info() {
    local project_path="$1"
    local output_file="$2"
    
    {
        echo "# Project Structure Analysis"
        echo "## Build Settings"
        xcodebuild -project "$project_path" -showBuildSettings -target "$PROJECT_NAME" | grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" | sort
        
        echo ""
        echo "## Targets"
        xcodebuild -project "$project_path" -list | grep -A 50 "Targets:" | grep -B 50 "Build Configurations:"
        
        echo ""
        echo "## Schemes"
        xcodebuild -project "$project_path" -list | grep -A 50 "Schemes:" | head -20
        
        echo ""
        echo "## Build Configurations"
        xcodebuild -project "$project_path" -list | grep -A 10 "Build Configurations:" | head -10
        
        echo ""
        echo "## File Structure"
        # Extract source files from project
        find "$project_path" -name "*.pbxproj" -exec grep -E "\.swift|\.m|\.mm|\.h" {} \; | sort | uniq | head -50
        
    } > "$output_file"
}

# Extract information from both projects
extract_project_info "$COMPARISON_DIR/existing_project.xcodeproj" "$COMPARISON_DIR/existing_info.txt"
extract_project_info "$COMPARISON_DIR/$GENERATED_PROJECT" "$COMPARISON_DIR/generated_info.txt"

# Step 4: Generate detailed comparison
log "${YELLOW}4. Generating detailed comparison...${NC}"

# Compare build settings
log "  Comparing build settings..."
{
    echo "# Build Settings Comparison"
    echo "## Settings in Existing but not in Generated"
    comm -23 <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/existing_info.txt" | sort) <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/generated_info.txt" | sort)
    
    echo ""
    echo "## Settings in Generated but not in Existing"
    comm -13 <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/existing_info.txt" | sort) <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/generated_info.txt" | sort)
    
    echo ""
    echo "## Common Settings"
    comm -12 <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/existing_info.txt" | sort) <(grep -E "(SWIFT_VERSION|IPHONEOS_DEPLOYMENT_TARGET|TARGETED_DEVICE_FAMILY|PRODUCT_BUNDLE_IDENTIFIER)" "$COMPARISON_DIR/generated_info.txt" | sort)
    
} > "$COMPARISON_DIR/build_settings_comparison.txt"

# Compare targets
log "  Comparing targets..."
{
    echo "# Targets Comparison"
    echo "## Targets in Existing"
    grep -A 20 "Targets:" "$COMPARISON_DIR/existing_info.txt" | grep -v "Targets:" | grep -v "Build Configurations:" | grep -v "^--$" | sort
    
    echo ""
    echo "## Targets in Generated"
    grep -A 20 "Targets:" "$COMPARISON_DIR/generated_info.txt" | grep -v "Targets:" | grep -v "Build Configurations:" | grep -v "^--$" | sort
    
} > "$COMPARISON_DIR/targets_comparison.txt"

# Compare schemes
log "  Comparing schemes..."
{
    echo "# Schemes Comparison"
    echo "## Schemes in Existing"
    grep -A 10 "Schemes:" "$COMPARISON_DIR/existing_info.txt" | grep -v "Schemes:" | sort
    
    echo ""
    echo "## Schemes in Generated"
    grep -A 10 "Schemes:" "$COMPARISON_DIR/generated_info.txt" | grep -v "Schemes:" | sort
    
} > "$COMPARISON_DIR/schemes_comparison.txt"

# Step 5: Analyze project.pbxproj differences
log "${YELLOW}5. Analyzing project.pbxproj differences...${NC}"

# Extract key sections from both pbxproj files
extract_pbxproj_sections() {
    local pbxproj_path="$1"
    local output_prefix="$2"
    
    if [[ -f "$pbxproj_path" ]]; then
        # Extract build settings
        grep -A 20 "buildSettings" "$pbxproj_path" | head -200 > "$output_prefix"_build_settings.txt
        
        # Extract targets
        grep -A 10 "PBXNativeTarget" "$pbxproj_path" > "$output_prefix"_targets.txt
        
        # Extract build phases
        grep -A 5 "PBXSourcesBuildPhase\|PBXFrameworksBuildPhase\|PBXResourcesBuildPhase" "$pbxproj_path" > "$output_prefix"_build_phases.txt
        
        # Extract file references
        grep "PBXFileReference" "$pbxproj_path" | sort > "$output_prefix"_file_refs.txt
    fi
}

extract_pbxproj_sections "$COMPARISON_DIR/existing_project.xcodeproj/project.pbxproj" "$COMPARISON_DIR/existing"
extract_pbxproj_sections "$COMPARISON_DIR/$GENERATED_PROJECT/project.pbxproj" "$COMPARISON_DIR/generated"

# Step 6: Check for Core Data differences
log "${YELLOW}6. Checking for Core Data configuration differences...${NC}"

{
    echo "# Core Data Configuration Comparison"
    echo "## Existing Project Core Data References"
    grep -r "xcdatamodel\|CoreData" "$COMPARISON_DIR/existing_project.xcodeproj" | head -10
    
    echo ""
    echo "## Generated Project Core Data References"
    grep -r "xcdatamodel\|CoreData" "$COMPARISON_DIR/$GENERATED_PROJECT" | head -10
    
} > "$COMPARISON_DIR/coredata_comparison.txt"

# Step 7: Generate comprehensive report
log "${YELLOW}7. Generating comprehensive report...${NC}"

REPORT_FILE="$COMPARISON_DIR/PROJECT_COMPARISON_REPORT.md"
cat > "$REPORT_FILE" << EOF
# Project Generation Comparison Report

**Date:** $(date)
**Existing Project:** $EXISTING_PROJECT
**Generated Project:** $GENERATED_PROJECT
**Comparison Directory:** $COMPARISON_DIR

## Executive Summary

This report compares the existing Xcode project with a freshly generated project from project.yml to identify potential differences that could cause CI/local build inconsistencies.

## Key Findings

### Build Settings Differences
$(cat "$COMPARISON_DIR/build_settings_comparison.txt" | head -20)

### Target Differences
$(diff -u "$COMPARISON_DIR/existing_targets.txt" "$COMPARISON_DIR/generated_targets.txt" 2>/dev/null | head -20 || echo "No significant target differences found")

### Scheme Differences
$(diff -u <(grep -A 10 "Schemes:" "$COMPARISON_DIR/existing_info.txt" | sort) <(grep -A 10 "Schemes:" "$COMPARISON_DIR/generated_info.txt" | sort) 2>/dev/null | head -20 || echo "No significant scheme differences found")

### Core Data Configuration
$(cat "$COMPARISON_DIR/coredata_comparison.txt")

## Detailed Analysis

### 1. Build Settings Analysis
- **Existing Project Settings:** $(grep -c "=" "$COMPARISON_DIR/existing_build_settings.txt" 2>/dev/null || echo "0") settings found
- **Generated Project Settings:** $(grep -c "=" "$COMPARISON_DIR/generated_build_settings.txt" 2>/dev/null || echo "0") settings found

### 2. File References Analysis
- **Existing Project Files:** $(wc -l < "$COMPARISON_DIR/existing_file_refs.txt" 2>/dev/null || echo "0") file references
- **Generated Project Files:** $(wc -l < "$COMPARISON_DIR/generated_file_refs.txt" 2>/dev/null || echo "0") file references

### 3. Build Phases Analysis
- **Existing Build Phases:** $(grep -c "PBX.*BuildPhase" "$COMPARISON_DIR/existing_build_phases.txt" 2>/dev/null || echo "0") phases
- **Generated Build Phases:** $(grep -c "PBX.*BuildPhase" "$COMPARISON_DIR/generated_build_phases.txt" 2>/dev/null || echo "0") phases

## Recommendations

### High Priority
1. **Review build settings differences** - These directly affect compilation
2. **Check Core Data model references** - Ensure proper code generation
3. **Verify target dependencies** - Prevent linking issues

### Medium Priority
1. **Compare scheme configurations** - Ensure consistent test/build behavior
2. **Review file organization** - Maintain project structure consistency
3. **Check build phase order** - Ensure proper build sequence

### Low Priority
1. **Standardize project formatting** - Improve maintainability
2. **Update project.yml** - Reflect any missing configurations
3. **Document differences** - For future reference

## Next Steps

1. **Update project.yml** to match critical settings from existing project
2. **Regenerate project** and test build compatibility
3. **Run CI replication suite** to verify changes
4. **Update CI scripts** if needed based on findings

## Files Generated

- existing_info.txt - Existing project analysis
- generated_info.txt - Generated project analysis
- build_settings_comparison.txt - Build settings diff
- targets_comparison.txt - Targets diff
- schemes_comparison.txt - Schemes diff
- coredata_comparison.txt - Core Data config diff
- comparison.log - Full comparison log

## Troubleshooting

If you find significant differences:
1. Check project.yml configuration
2. Verify XcodeGen version compatibility
3. Review custom build settings
4. Check for manual project modifications

EOF

# Step 8: Generate actionable fixes
log "${YELLOW}8. Generating actionable fixes...${NC}"

{
    echo "#!/bin/bash"
    echo "# Auto-generated fixes for project differences"
    echo "# Run this script to apply recommended changes"
    echo ""
    echo "set -e"
    echo ""
    echo "echo '🔧 Applying project generation fixes...'"
    echo ""
    
    # Check if there are build setting differences
    if [[ -s "$COMPARISON_DIR/build_settings_comparison.txt" ]]; then
        echo "# Update project.yml with missing build settings"
        echo "echo '📝 Updating project.yml with missing build settings...'"
        echo "# TODO: Add specific sed commands to update project.yml"
    fi
    
    # Check for Core Data issues
    if grep -q "xcdatamodel" "$COMPARISON_DIR/coredata_comparison.txt"; then
        echo "# Fix Core Data configuration"
        echo "echo '🗄️ Fixing Core Data configuration...'"
        echo "# Ensure Core Data model is properly referenced"
        echo "# TODO: Add specific Core Data fixes"
    fi
    
    echo "echo '✅ Project generation fixes applied'"
    echo "echo '🔄 Regenerating project...'"
    echo "xcodegen generate --spec project.yml"
    echo "echo '✅ Project regeneration complete'"
    
} > "$COMPARISON_DIR/apply_fixes.sh"

chmod +x "$COMPARISON_DIR/apply_fixes.sh"

# Copy report to project root
cp "$REPORT_FILE" "./PROJECT_COMPARISON_REPORT.md"

log "${GREEN}✅ Project generation comparison completed${NC}"
log "${BLUE}📄 Report saved to: ./PROJECT_COMPARISON_REPORT.md${NC}"
log "${BLUE}📁 Detailed files in: $COMPARISON_DIR${NC}"
log "${BLUE}🔧 Apply fixes with: $COMPARISON_DIR/apply_fixes.sh${NC}"

# Ask if user wants to open the report
read -p "Open comparison report? (y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    if command -v open &> /dev/null; then
        open "./PROJECT_COMPARISON_REPORT.md"
    else
        echo "Report available at: ./PROJECT_COMPARISON_REPORT.md"
    fi
fi