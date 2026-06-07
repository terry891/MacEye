#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/EyeBreak.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

echo "Cleaning..."
rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compiling (universal: arm64 + x86_64)..."
SLICES=()
swiftc -swift-version 5 -O -target arm64-apple-macosx13.0 \
  -o build/.eb_arm64 Sources/EyeBreak/*.swift
SLICES+=(build/.eb_arm64)
if swiftc -swift-version 5 -O -target x86_64-apple-macosx13.0 \
     -o build/.eb_x86_64 Sources/EyeBreak/*.swift 2>/dev/null; then
  SLICES+=(build/.eb_x86_64)
else
  echo "  (x86_64 SDK slice unavailable — building arm64 only)"
fi
lipo -create "${SLICES[@]}" -o "$BIN_DIR/EyeBreak"
rm -f build/.eb_arm64 build/.eb_x86_64

echo "Assembling bundle..."
cp Info.plist "$APP/Contents/Info.plist"
if [[ -f Resources/AppIcon.icns ]]; then
  cp Resources/AppIcon.icns "$RES_DIR/AppIcon.icns"
fi

echo "Ad-hoc signing..."
codesign --force --deep --sign - "$APP"

echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
  echo "Installing to /Applications..."
  rm -rf "/Applications/EyeBreak.app"
  cp -R "$APP" "/Applications/EyeBreak.app"
  echo "Launching..."
  open "/Applications/EyeBreak.app"
fi

if [[ "${1:-}" == "--run" ]]; then
  open "$APP"
fi
