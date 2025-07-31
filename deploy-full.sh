#!/bin/bash

# GrouperPlus Full Deployment Script
# Complete build and deploy pipeline with validation

set -e

PROJECT_NAME="GrouperPlus"
BUILD_DIR="build"

echo "🚀 Starting full deployment pipeline for $PROJECT_NAME..."

# Check prerequisites
echo "📋 Checking prerequisites..."

# Check if Node.js is available
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed"
    exit 1
fi

# Check if npm is available
if ! command -v npm &> /dev/null; then
    echo "❌ npm is required but not installed"
    exit 1
fi

# Check environment variables
if [ -z "$CURSEFORGE_API_TOKEN" ]; then
    echo "❌ CURSEFORGE_API_TOKEN environment variable is required"
    echo "💡 Set it with: export CURSEFORGE_API_TOKEN=your_token_here"
    exit 1
fi

if [ -z "$CURSEFORGE_PROJECT_ID" ]; then
    echo "❌ CURSEFORGE_PROJECT_ID environment variable is required"
    echo "💡 Set it with: export CURSEFORGE_PROJECT_ID=your_project_id_here"
    exit 1
fi

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

# Run build
echo "🔨 Building addon package..."
./build.sh

# Validate build output
if [ ! -f "$BUILD_DIR/${PROJECT_NAME}.zip" ]; then
    echo "❌ Build failed - package not found"
    exit 1
fi

# Show build info
echo "✅ Build successful!"
echo "📦 Package: $BUILD_DIR/${PROJECT_NAME}.zip"
echo "📏 Size: $(du -h $BUILD_DIR/${PROJECT_NAME}.zip | cut -f1)"

# Confirm deployment
echo ""
echo "🚨 Ready to deploy to CurseForge!"
echo "Project ID: $CURSEFORGE_PROJECT_ID"
echo "Package: $BUILD_DIR/${PROJECT_NAME}.zip"
echo ""
read -p "Continue with deployment? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Deployment cancelled"
    exit 1
fi

# Deploy
echo "🚀 Deploying to CurseForge..."
node deploy.js

echo "✅ Deployment pipeline completed successfully!"
echo ""
echo "📋 Next steps:"
echo "1. Check your CurseForge project page for the uploaded file"
echo "2. The file will need approval before it's publicly available"
echo "3. Update any project descriptions or screenshots as needed"