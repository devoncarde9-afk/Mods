#!/bin/bash
set -e

PRODUCT="yeeps_companion.dylib"
SOURCE="yeeps_companion.m"

echo "🔨  Building $PRODUCT for iOS ..."

clang \
    -dynamiclib \
    -arch arm64 \
    -fobjc-arc \
    -fmodules \
    -isysroot $(xcrun --sdk iphoneos --show-sdk-path) \
    -framework UIKit \
    -framework Foundation \
    -framework QuartzCore \
    -miphoneos-version-min=14.0 \
    -install_name @rpath/$PRODUCT \
    -o "$PRODUCT" \
    "$SOURCE"

echo "✅  Built: $PRODUCT"
