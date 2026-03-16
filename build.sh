#!/bin/bash
set -e

PRODUCT="yeeps_companion.dylib"
SOURCE="yeeps_companion.m"

echo "🔨  Building $PRODUCT ..."

clang \
    -dynamiclib \
    -arch arm64 -arch x86_64 \
    -fobjc-arc \
    -fmodules \
    -framework Cocoa \
    -framework QuartzCore \
    -mmacosx-version-min=11.0 \
    -install_name @rpath/$PRODUCT \
    -o "$PRODUCT" \
    "$SOURCE"

echo "✅  Built: $PRODUCT"
