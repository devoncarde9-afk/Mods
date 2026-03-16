#!/bin/bash
# ─────────────────────────────────────────────────────────────────
# build.sh — Yeeps Companion dylib builder
# Requires: macOS + Xcode Command Line Tools
#   xcode-select --install
# ─────────────────────────────────────────────────────────────────
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

echo "✅  Built: $(pwd)/$PRODUCT"
echo ""
echo "── How to use ──────────────────────────────────────────────"
echo ""
echo "  Option A — Inject into ANY running app (e.g. Finder):"
echo "    DYLD_INSERT_LIBRARIES=\$(pwd)/$PRODUCT /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder"
echo ""
echo "  Option B — Load from your own app at runtime:"
echo "    dlopen(\"/path/to/$PRODUCT\", RTLD_NOW);"
echo ""
echo "  Option C — Link at build time (add to your Xcode target):"
echo "    Drag $PRODUCT into your Xcode project → Embed & Sign"
echo ""
echo "⚠️  SIP note: DYLD_INSERT_LIBRARIES is blocked on SIP-protected"
echo "    binaries. Use your own app binary, or disable SIP in Recovery"
echo "    Mode for testing only."
echo "────────────────────────────────────────────────────────────"
