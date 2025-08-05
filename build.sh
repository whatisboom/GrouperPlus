#!/bin/bash

# GrouperPlus Build Script
# Creates a packaged addon ready for CurseForge upload

set -e

PROJECT_NAME="GrouperPlus"
BUILD_DIR="build"
PACKAGE_DIR="$BUILD_DIR/$PROJECT_NAME"

# Extract version from TOC file
VERSION=$(grep "## Version:" *.toc | sed 's/## Version: //' | tr -d '\r')
if [ -z "$VERSION" ]; then
    echo "Warning: Could not extract version from TOC file, using 'unknown'"
    VERSION="unknown"
fi

echo "Starting build process for $PROJECT_NAME v$VERSION..."

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$PACKAGE_DIR"

# Copy addon files
echo "Copying addon files..."
cp -r libs "$PACKAGE_DIR/"
cp -r modules "$PACKAGE_DIR/"
cp -r textures "$PACKAGE_DIR/" 2>/dev/null || echo "No textures directory found, skipping..."
cp *.lua "$PACKAGE_DIR/"
cp *.toc "$PACKAGE_DIR/"
cp CHANGELOG.md "$PACKAGE_DIR/" 2>/dev/null || echo "No CHANGELOG.md found, skipping..."
cp README.md "$PACKAGE_DIR/" 2>/dev/null || echo "No README.md found, skipping..."

# Ensure we don't include any deployment or development files
echo "Cleaning up development files..."
rm -f "$PACKAGE_DIR"/*.sh 2>/dev/null || true
rm -f "$PACKAGE_DIR"/*.js 2>/dev/null || true
rm -f "$PACKAGE_DIR"/*.json 2>/dev/null || true
rm -f "$PACKAGE_DIR"/.gitignore 2>/dev/null || true
rm -f "$PACKAGE_DIR"/CLAUDE.md 2>/dev/null || true
rm -rf "$PACKAGE_DIR"/node_modules 2>/dev/null || true
rm -rf "$PACKAGE_DIR"/build 2>/dev/null || true

# Create archive with version in filename
cd "$BUILD_DIR"
ARCHIVE_NAME="${PROJECT_NAME}-v${VERSION}.zip"
echo "Creating archive: $ARCHIVE_NAME"
zip -r "$ARCHIVE_NAME" "$PROJECT_NAME/"

echo "Build complete! Archive created at: $BUILD_DIR/$ARCHIVE_NAME"
echo "Archive size: $(du -h $ARCHIVE_NAME | cut -f1)"