#!/bin/bash
# Script to check Swift compilation errors using xcodebuild
# Run this script to see current build errors

cd "$(dirname "$0")"

echo "Checking for Xcode build errors..."
echo "=================================="
echo ""

# Try to build and capture errors
xcodebuild -project Momento.xcodeproj \
    -scheme Momento \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    clean build 2>&1 | \
    grep -A 3 "error:" | \
    head -30

echo ""
echo "=================================="
echo "Build check complete"
