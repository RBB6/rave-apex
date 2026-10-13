#!/usr/bin/env bash
# Build RaveApexCore.dylib against the REAL iOS SDK on a macOS runner.
# This removes the stub-linking approach entirely: real UIKit/Foundation headers,
# real framework linkage, correct ObjC class metadata -> no runtime realization
# crashes. Output is an UNSIGNED arm64 iOS dylib ready for Sideloadly injection.
set -euo pipefail

cd "$(dirname "$0")/.."
mkdir -p build

SDK="$(xcrun --sdk iphoneos --show-sdk-path)"
echo "iOS SDK: $SDK"
CLANG="$(xcrun --sdk iphoneos --find clang)"
echo "clang:   $CLANG"

"$CLANG" \
    -arch arm64 \
    -isysroot "$SDK" \
    -dynamiclib \
    -fobjc-arc -fobjc-arc-exceptions \
    -miphoneos-version-min=12.0 \
    -Wno-deprecated-declarations -Wno-nullability-completeness \
    -framework UIKit \
    -framework Foundation \
    -framework AVFoundation \
    -framework AVKit \
    -framework QuartzCore \
    -framework CoreGraphics \
    -install_name "@executable_path/RaveApexCore.dylib" \
    src/RaveApexTweak.m src/RaveApexMenuUI.m src/RaveApexHooks.m \
    -o build/RaveApexCore.dylib

# Ship UNSIGNED so the install tool (Sideloadly) signs it with the app's identity.
codesign --remove-signature build/RaveApexCore.dylib 2>/dev/null || true

echo "=== Built build/RaveApexCore.dylib ==="
file build/RaveApexCore.dylib || true
otool -l build/RaveApexCore.dylib 2>/dev/null | grep -A3 LC_BUILD_VERSION || true
echo "size: $(stat -f%z build/RaveApexCore.dylib 2>/dev/null || stat -c%s build/RaveApexCore.dylib) bytes"
