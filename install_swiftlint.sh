#!/bin/bash

# SwiftLint Installation Script for Momento
# This script installs SwiftLint and sets up Xcode integration

set -e

echo "🔧 Installing SwiftLint..."

# Check if SwiftLint is already installed
if command -v swiftlint &> /dev/null; then
    echo "✅ SwiftLint is already installed: $(swiftlint version)"
    exit 0
fi

# Try to install via Homebrew first (if available)
if command -v brew &> /dev/null; then
    echo "📦 Installing SwiftLint via Homebrew..."
    brew install swiftlint
    echo "✅ SwiftLint installed successfully!"
    exit 0
fi

# If Homebrew is not available, install the .pkg
if [ -f "/tmp/SwiftLint.pkg" ]; then
    echo "📦 Installing SwiftLint from package..."
    sudo installer -pkg /tmp/SwiftLint.pkg -target /
    echo "✅ SwiftLint installed successfully!"
else
    echo "⚠️  SwiftLint package not found."
    echo "Please install Homebrew first:"
    echo "  /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "Then run: brew install swiftlint"
    exit 1
fi

