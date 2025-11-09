#!/bin/bash

# Quick build and run script for Momento app
# Usage: ./run_simulator.sh

set -e

echo "🚀 Building and running Momento..."

# Navigate to project directory
cd "$(dirname "$0")"

# Open simulator if not already running
open -a Simulator

# Wait a moment for simulator to boot
sleep 2

# Build and run the app
xcodebuild \
  -project Momento.xcodeproj \
  -scheme Momento \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
  -derivedDataPath ./build \
  clean build

# Install the app
APP_PATH=$(find ./build/Build/Products/Debug-iphonesimulator -name "*.app" -type d | head -n 1)

if [ -z "$APP_PATH" ]; then
  echo "❌ Could not find built app"
  exit 1
fi

# Get booted simulator UDID
SIMULATOR_UDID=$(xcrun simctl list devices | grep "iPhone 15 Pro (Booted)" | grep -o -E '\([A-F0-9-]+\)' | tr -d '()')

if [ -z "$SIMULATOR_UDID" ]; then
  echo "⚠️  No booted simulator found, booting iPhone 15 Pro..."
  SIMULATOR_UDID=$(xcrun simctl list devices | grep "iPhone 15 Pro" | head -n 1 | grep -o -E '\([A-F0-9-]+\)' | tr -d '()')
  xcrun simctl boot "$SIMULATOR_UDID" 2>/dev/null || true
  sleep 3
fi

# Install and launch
xcrun simctl install "$SIMULATOR_UDID" "$APP_PATH"
xcrun simctl launch "$SIMULATOR_UDID" com.momento.Momento

echo "✅ Momento is running!"

