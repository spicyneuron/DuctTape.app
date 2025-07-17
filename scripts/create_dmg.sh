#!/bin/bash

# Script to create DMG using create-dmg
# Usage: ./create_dmg.sh <path_to_notarized_app>

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    print_error "create-dmg is not installed. Please install it first:"
    echo "  brew install create-dmg"
    exit 1
fi

# Check if app path is provided
if [ -z "$1" ]; then
    print_error "Usage: $0 <path_to_notarized_app>"
    echo "Example: $0 /path/to/DuctTape.app"
    exit 1
fi

APP_PATH="$1"
APP_NAME=$(basename "$APP_PATH" .app)

# Verify the app exists
if [ ! -d "$APP_PATH" ]; then
    print_error "App not found at: $APP_PATH"
    exit 1
fi

# Get app version from the app bundle
APP_VERSION=$(defaults read "$APP_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "unknown")
BUILD_NUMBER=$(defaults read "$APP_PATH/Contents/Info" CFBundleVersion 2>/dev/null || echo "unknown")

print_info "Creating DMG for $APP_NAME version $APP_VERSION (build $BUILD_NUMBER)"

# Set output paths
OUTPUT_DIR="$(dirname "$(dirname "$0")")/dist"
DMG_NAME="${APP_NAME}-${APP_VERSION}.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Remove existing DMG if it exists
if [ -f "$DMG_PATH" ]; then
    print_warning "Removing existing DMG: $DMG_PATH"
    rm "$DMG_PATH"
fi

print_info "Creating DMG..."

# Create DMG with create-dmg
create-dmg \
    --volname "$APP_NAME $APP_VERSION" \
    --volicon "$APP_PATH/Contents/Resources/AppIcon.icns" \
    --window-pos 200 120 \
    --window-size 800 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 200 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 600 185 \
    --codesign "Developer ID Application: Spicy Neuron LLC" \
    "$DMG_PATH" \
    "$APP_PATH"

if [ $? -eq 0 ]; then
    print_info "DMG created successfully: $DMG_PATH"
    print_info "DMG size: $(du -h "$DMG_PATH" | cut -f1)"

    # Optional: Open the output directory
    if command -v open &> /dev/null; then
        print_info "Opening output directory..."
        open "$OUTPUT_DIR"
    fi
else
    print_error "Failed to create DMG"
    exit 1
fi