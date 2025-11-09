#!/bin/bash

# SwiftLint Runner for Momento
# Usage: ./lint.sh [--fix] [--strict]

cd "$(dirname "$0")"

# Check if SwiftLint is installed
if ! command -v swiftlint &> /dev/null; then
    echo "❌ SwiftLint is not installed."
    echo "Run: ./install_swiftlint.sh"
    exit 1
fi

echo "🔍 Running SwiftLint..."

# Parse arguments
FIX_MODE=false
STRICT_MODE=false

for arg in "$@"; do
    case $arg in
        --fix)
            FIX_MODE=true
            ;;
        --strict)
            STRICT_MODE=true
            ;;
    esac
done

# Run SwiftLint
if [ "$FIX_MODE" = true ]; then
    echo "🔧 Auto-fixing issues..."
    swiftlint --fix --config .swiftlint.yml
fi

if [ "$STRICT_MODE" = true ]; then
    swiftlint --strict --config .swiftlint.yml
else
    swiftlint --config .swiftlint.yml
fi

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo "✅ No linting issues found!"
else
    echo "⚠️  Found linting issues. Run './lint.sh --fix' to auto-fix some issues."
fi

exit $EXIT_CODE

