#!/bin/bash

# Dynamic Simulator Detection Script
# Finds the best available iPad simulator for CI builds

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to get available simulators
get_available_simulators() {
    xcrun simctl list devices available | grep -E "iPad|iPhone" | grep -v "Apple Watch" | grep -v "Apple TV"
}

# Function to find best iPad simulator
find_best_ipad_simulator() {
    local simulators=$(get_available_simulators)
    
    # Priority order for iPad simulators
    local priority_ipads=(
        "iPad Pro (12.9-inch) (6th generation)"
        "iPad Pro (12.9-inch) (5th generation)"
        "iPad Pro (13-inch) (M4)"
        "iPad Pro 13-inch (M4)"
        "iPad Pro (11-inch) (4th generation)"
        "iPad Pro 11-inch (M4)"
        "iPad Air (5th generation)"
        "iPad Air 13-inch (M2)"
        "iPad Air 11-inch (M2)"
        "iPad (10th generation)"
        "iPad mini (6th generation)"
        "iPad mini (A17 Pro)"
    )
    
    # Check for each priority iPad
    for ipad in "${priority_ipads[@]}"; do
        if echo "$simulators" | grep -q "$ipad"; then
            echo "$ipad"
            return 0
        fi
    done
    
    # Fallback: get first available iPad
    local fallback_ipad=$(echo "$simulators" | grep "iPad" | head -1 | sed 's/.*name=\([^,]*\),.*/\1/')
    if [[ -n "$fallback_ipad" ]]; then
        echo "$fallback_ipad"
        return 0
    fi
    
    return 1
}

# Function to find best iPhone simulator
find_best_iphone_simulator() {
    local simulators=$(get_available_simulators)
    
    # Priority order for iPhone simulators
    local priority_iphones=(
        "iPhone 15 Pro"
        "iPhone 15 Pro Max"
        "iPhone 15"
        "iPhone 15 Plus"
        "iPhone 16 Pro"
        "iPhone 16 Pro Max"
        "iPhone 16"
        "iPhone 16 Plus"
        "iPhone 14 Pro"
        "iPhone 14 Pro Max"
        "iPhone 14"
        "iPhone 14 Plus"
        "iPhone SE (3rd generation)"
    )
    
    # Check for each priority iPhone
    for iphone in "${priority_iphones[@]}"; do
        if echo "$simulators" | grep -q "$iphone"; then
            echo "$iphone"
            return 0
        fi
    done
    
    # Fallback: get first available iPhone
    local fallback_iphone=$(echo "$simulators" | grep "iPhone" | head -1 | sed 's/.*name=\([^,]*\),.*/\1/')
    if [[ -n "$fallback_iphone" ]]; then
        echo "$fallback_iphone"
        return 0
    fi
    
    return 1
}

# Function to get OS version for a simulator
get_simulator_os_version() {
    local simulator_name="$1"
    local simulator_line=$(xcrun simctl list devices available | grep "$simulator_name" | head -1)
    
    # Extract OS version from the line format like "OS=17.2"
    if [[ "$simulator_line" =~ OS=([0-9]+\.[0-9]+) ]]; then
        echo "${BASH_REMATCH[1]}"
    else
        echo "latest"
    fi
}

# Function to create destination string
create_destination_string() {
    local device_type="${1:-iPad}"
    local simulator_name=""
    
    case "$device_type" in
        iPad|ipad)
            simulator_name=$(find_best_ipad_simulator)
            ;;
        iPhone|iphone)
            simulator_name=$(find_best_iphone_simulator)
            ;;
        *)
            echo -e "${RED}❌ Unknown device type: $device_type${NC}" >&2
            echo "Supported types: iPad, iPhone" >&2
            exit 1
            ;;
    esac
    
    if [[ -z "$simulator_name" ]]; then
        echo -e "${RED}❌ No $device_type simulator found${NC}" >&2
        exit 1
    fi
    
    local os_version=$(get_simulator_os_version "$simulator_name")
    
    # Always use latest to avoid OS version mismatches
    echo "platform=iOS Simulator,name=$simulator_name,OS=latest"
}

# Function to get simulator ID
get_simulator_id() {
    local simulator_name="$1"
    local device_id=$(xcrun simctl list devices available | grep "$simulator_name" | head -1 | grep -E -o "([0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12})")
    
    if [[ -n "$device_id" ]]; then
        echo "$device_id"
    else
        echo -e "${RED}❌ Could not find device ID for: $simulator_name${NC}" >&2
        exit 1
    fi
}

# Function to list available simulators
list_simulators() {
    echo -e "${BLUE}Available iOS Simulators:${NC}"
    echo "========================="
    get_available_simulators
}

# Function to show help
show_help() {
    echo -e "${BLUE}Dynamic Simulator Detection Script${NC}"
    echo "=================================="
    echo ""
    echo "Usage: $0 [command] [device_type]"
    echo ""
    echo "Commands:"
    echo "  destination [iPad|iPhone]  - Get destination string for xcodebuild"
    echo "  name [iPad|iPhone]         - Get simulator name only"
    echo "  id [iPad|iPhone]           - Get simulator device ID"
    echo "  list                       - List all available simulators"
    echo "  help                       - Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 destination iPad        # Get iPad destination string"
    echo "  $0 name iPhone             # Get iPhone simulator name"
    echo "  $0 id iPad                 # Get iPad simulator device ID"
    echo "  $0 list                    # List all available simulators"
    echo ""
    echo "Usage in CI scripts:"
    echo "  DESTINATION=\$($0 destination iPad)"
    echo "  xcodebuild -destination \"\$DESTINATION\" ..."
}

# Main command handling
case "${1:-help}" in
    destination)
        create_destination_string "${2:-iPad}"
        ;;
    name)
        case "${2:-iPad}" in
            iPad|ipad)
                find_best_ipad_simulator
                ;;
            iPhone|iphone)
                find_best_iphone_simulator
                ;;
            *)
                echo -e "${RED}❌ Unknown device type: ${2}${NC}" >&2
                exit 1
                ;;
        esac
        ;;
    id)
        case "${2:-iPad}" in
            iPad|ipad)
                simulator_name=$(find_best_ipad_simulator)
                ;;
            iPhone|iphone)
                simulator_name=$(find_best_iphone_simulator)
                ;;
            *)
                echo -e "${RED}❌ Unknown device type: ${2}${NC}" >&2
                exit 1
                ;;
        esac
        get_simulator_id "$simulator_name"
        ;;
    list)
        list_simulators
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}" >&2
        show_help
        exit 1
        ;;
esac