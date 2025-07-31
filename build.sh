#!/bin/bash

# GrouperPlus Build Script
# Creates a packaged addon ready for CurseForge upload

set -e

PROJECT_NAME="GrouperPlus"
BUILD_DIR="build"
PACKAGE_DIR="$BUILD_DIR/$PROJECT_NAME"

echo "Starting build process for $PROJECT_NAME..."

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

# Ensure we don't include any deployment or development files
echo "Cleaning up development files..."
rm -f "$PACKAGE_DIR"/*.sh 2>/dev/null || true
rm -f "$PACKAGE_DIR"/*.js 2>/dev/null || true
rm -f "$PACKAGE_DIR"/*.json 2>/dev/null || true
rm -f "$PACKAGE_DIR"/.gitignore 2>/dev/null || true
rm -f "$PACKAGE_DIR"/CLAUDE.md 2>/dev/null || true
rm -rf "$PACKAGE_DIR"/node_modules 2>/dev/null || true
rm -rf "$PACKAGE_DIR"/build 2>/dev/null || true

# Create archive
cd "$BUILD_DIR"
echo "Creating archive..."
zip -r "${PROJECT_NAME}.zip" "$PROJECT_NAME/"

echo "Build complete! Archive created at: $BUILD_DIR/${PROJECT_NAME}.zip"
echo "Archive size: $(du -h ${PROJECT_NAME}.zip | cut -f1)"