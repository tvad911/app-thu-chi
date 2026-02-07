#!/bin/bash
set -e

echo "🚀 Starting Release Build Process..."

# 1. Clean (Optional - remove comment to enable)
# echo "🧹 Cleaning project..."
# flutter clean
# flutter pub get

# 2. Build Linux
echo "🐧 Building Linux Release..."
flutter build linux --release
echo "✅ Linux Build Complete: build/linux/x64/release/bundle/thuchi_app"

# 3. Build Android APK
echo "🤖 Building Android APK Release..."
flutter build apk --release
echo "✅ Android Build Complete: build/app/outputs/flutter-apk/app-release.apk"

echo "🎉 Build Process Finished Successfully!"
