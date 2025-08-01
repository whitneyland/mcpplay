#!/usr/bin/env zsh
set -euo pipefail

APP="RiffMCP.app"
DMG="RiffMCP-0.1.dmg"
IDENTITY="Developer ID Application: Lee Whitney (Z9P2U4WT64)"
KEYCHAIN_PROFILE="AC_NOTARY"   # whatever profile name you created with `xcrun notarytool store-credentials`

# 0) Ensure the app is already signed, notarised, and stapled
xcrun stapler staple "$APP"

# 1) Build the DMG with create-dmg
create-dmg \
  --volname "RiffMCP" \
  --volicon "$APP/Contents/Resources/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 540 330 \
  --icon-size 128 \
  --background "dmg-background.png" \
  --icon "$APP" 48 112 \
  --app-drop-link 356 112 \
  "$DMG" \
  "$APP"

# 2) Ask if DMG should be signed
echo "Sign the DMG? (y/n): "
read -r sign_dmg

if [[ "$sign_dmg" =~ ^[Yy]$ ]]; then
    echo "Signing $DMG..."
    codesign --sign "$IDENTITY" "$DMG"

    echo "Submitting $DMG for notarization..."
    xcrun notarytool submit "$DMG" --keychain-profile "$KEYCHAIN_PROFILE" --wait

    echo "Stapling $DMG..."
    xcrun stapler staple "$DMG"

    echo "✅  $DMG is signed, notarised, and ready to ship."
else
    echo "✅  $DMG created but not signed."
fi