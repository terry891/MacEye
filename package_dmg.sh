#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/EyeBreak.app"
VOL="EyeBreak"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Info.plist 2>/dev/null || echo 1.0)"
DMG="build/EyeBreak-${VERSION}.dmg"
STAGE="build/dmg_stage"

# Build the app first if it is missing.
if [[ ! -d "$APP" ]]; then
  echo "App not found — building..."
  ./build.sh
fi

echo "Staging DMG contents..."
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/EyeBreak.app"
ln -s /Applications "$STAGE/Applications"

cat > "$STAGE/INSTALL — Read Me.txt" <<'EOF'
EyeBreak 👀  — eye-strain break reminder

INSTALL
  1. Drag EyeBreak.app onto the Applications folder in this window.
  2. Open EyeBreak from Applications.

FIRST LAUNCH (important)
  EyeBreak is signed locally (ad-hoc), not with a paid Apple Developer ID,
  so macOS Gatekeeper will block it the first time. To open it anyway:

  Easiest (Terminal):
      xattr -dr com.apple.quarantine /Applications/EyeBreak.app
      open /Applications/EyeBreak.app

  Or via the UI:
      Try to open it once (it will be blocked), then go to
      System Settings → Privacy & Security → scroll down →
      click "Open Anyway" next to EyeBreak.

USING IT
  Look for the 👁 icon in the menu bar. Click it to take a break now,
  snooze, pause, or change the interval (default: every 30 minutes) and
  break length (default: 20 seconds). Enable "Open at Login" to keep it
  running in the background automatically.

UNINSTALL
  Quit from the menu, then delete /Applications/EyeBreak.app.
EOF

echo "Creating $DMG ..."
hdiutil create \
  -volname "$VOL" \
  -srcfolder "$STAGE" \
  -fs HFS+ \
  -format UDZO \
  -ov \
  "$DMG" >/dev/null

rm -rf "$STAGE"
SIZE="$(du -h "$DMG" | cut -f1 | tr -d ' ')"
echo "Built $DMG ($SIZE)"
