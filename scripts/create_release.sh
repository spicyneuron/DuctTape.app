#!/bin/bash

# Create a GitHub release with automatic version detection
# Usage: ./create_release.sh [release_notes]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Set release notes (default or custom)
RELEASE_CONTENT="${1:-Updates and improvements}"

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it first:"
    echo "  brew install gh"
    echo "  gh auth login"
    exit 1
fi

# Check if user is authenticated with GitHub
if ! gh auth status &> /dev/null; then
    print_error "Not authenticated with GitHub. Please run:"
    echo "  gh auth login"
    exit 1
fi

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
DIST_DIR="$PROJECT_ROOT/dist"

print_step "Extracting app version from Xcode project..."

# Extract marketing version from project.pbxproj
PROJECT_FILE="$PROJECT_ROOT/DuctTape.xcodeproj/project.pbxproj"
if [ ! -f "$PROJECT_FILE" ]; then
    print_error "Xcode project file not found: $PROJECT_FILE"
    exit 1
fi

# Extract the marketing version (first occurrence should be sufficient)
MARKETING_VERSION=$(grep -m 1 "MARKETING_VERSION" "$PROJECT_FILE" | sed 's/.*MARKETING_VERSION = \([^;]*\);.*/\1/' | tr -d ' ')

if [ -z "$MARKETING_VERSION" ]; then
    print_error "Could not extract marketing version from project file"
    exit 1
fi

print_info "Found marketing version: $MARKETING_VERSION"

# Set version tag
VERSION_TAG="v$MARKETING_VERSION"

print_step "Validating distribution files before creating release..."

# Check if dist directory exists
if [ ! -d "$DIST_DIR" ]; then
    print_error "Distribution directory not found: $DIST_DIR"
    echo "Please make sure you have built and packaged your app first."
    echo ""
    echo "To create the distribution:"
    echo "  1. Build your app in Xcode for release"
    echo "  2. Export/archive the app"
    echo "  3. Run: ./scripts/create_dmg.sh /path/to/DuctTape.app"
    exit 1
fi

# Look for DMG file matching the version
DMG_FILE="$DIST_DIR/DuctTape-$MARKETING_VERSION.dmg"

if [ ! -f "$DMG_FILE" ]; then
    print_error "DMG file not found: $DMG_FILE"
    echo "Available files in $DIST_DIR:"
    ls -la "$DIST_DIR" 2>/dev/null || echo "  (directory is empty)"
    echo ""
    echo "Please make sure you have:"
    echo "  1. Built your app for release"
    echo "  2. Created the DMG using: ./scripts/create_dmg.sh /path/to/DuctTape.app"
    echo ""
    echo "Expected DMG file: $DMG_FILE"
    exit 1
fi

print_info "✅ Found DMG file: $DMG_FILE"

print_step "Checking if version tag already exists..."

# Check if tag already exists
if git rev-parse "$VERSION_TAG" >/dev/null 2>&1; then
    print_warning "Tag $VERSION_TAG already exists"
    read -p "Do you want to delete the existing tag and recreate it? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Deleting existing tag $VERSION_TAG"
        git tag -d "$VERSION_TAG" 2>/dev/null || true
        git push --delete origin "$VERSION_TAG" 2>/dev/null || true
    else
        print_error "Aborting: Tag $VERSION_TAG already exists"
        exit 1
    fi
fi

print_step "Creating git tag..."

# Create and push the tag
git tag -a "$VERSION_TAG" -m "Release $VERSION_TAG"
git push origin "$VERSION_TAG"

print_info "✅ Created and pushed tag: $VERSION_TAG"

print_step "Creating GitHub release..."

# Create release notes
# Get previous tag for comparison
PREV_TAG=$(git describe --tags --abbrev=0 HEAD~1 2>/dev/null || echo "")

if [ -n "$PREV_TAG" ]; then
    RELEASE_NOTES="$(echo -e "$RELEASE_CONTENT")

Full Diff: https://github.com/$(gh repo view --json owner,name --jq '.owner.login + "/" + .name')/compare/$PREV_TAG...$VERSION_TAG"
else
    RELEASE_NOTES="$(echo -e "$RELEASE_CONTENT")"
fi

gh release create "$VERSION_TAG" \
    "$DMG_FILE" \
    --title "DuctTape $MARKETING_VERSION" \
    --notes "$RELEASE_NOTES" \
    --verify-tag

if [ $? -eq 0 ]; then
    print_info "Release created: $(gh release view "$VERSION_TAG" --json url --jq '.url')"
else
    print_error "Failed to create GitHub release"
    exit 1
fi
