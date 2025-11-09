#!/bin/bash

# Fix Xcode build issues
# Run this script if you get "No such module" errors

echo "🧹 Cleaning Xcode build artifacts..."

cd /Users/asad/Documents/Momento

# Remove derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/Momento-*

# Remove build folder
rm -rf build/

# Remove package caches
rm -rf .build/

echo "✅ Clean complete!"
echo ""
echo "📦 Now in Xcode:"
echo "   1. File → Packages → Reset Package Caches"
echo "   2. Product → Clean Build Folder (Shift+Cmd+K)"
echo "   3. Product → Build (Cmd+B)"
echo ""
echo "This should fix the 'No such module Supabase' error."

