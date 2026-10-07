#!/usr/bin/env bash
# Builds a signed Welp.app into ./build.
#
# Signing with a stable identity matters: macOS ties the Accessibility permission to the
# code signature, so an ad-hoc signed build would need the permission again after every
# rebuild. Override the identity with CODESIGN_IDENTITY="..." if needed.
#
# The official app is the Welp Pro build (ee/). Without ee/, or with WELP_FOSS_ONLY=1, it
# is the open-source core on its own; both are installed as Welp.app.
#
# Release builds (scripts/release.sh) also set:
#   UNIVERSAL=1        build for both Apple silicon and Intel
#   VERSION=1.2.3      CFBundleShortVersionString
#   BUILD_NUMBER=42    CFBundleVersion
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Welp.app"
if [[ -d ee/Sources && -z "${WELP_FOSS_ONLY:-}" ]]; then
  EXECUTABLE=WelpPro
  BUNDLES=(Welp_WelpApp.bundle Welp_WelpProEdition.bundle)
else
  EXECUTABLE=Welp
  BUNDLES=(Welp_WelpApp.bundle)
fi

if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  # `swift build --arch arm64 --arch x86_64` goes through the Xcode build system, which
  # cannot resolve the StringCatalogCompiler plugin; build each slice and merge them.
  BIN_DIRS=()
  for ARCH in arm64 x86_64; do
    swift build -c release --product "$EXECUTABLE" --triple "$ARCH-apple-macosx14.0"
    BIN_DIRS+=("$(swift build -c release --triple "$ARCH-apple-macosx14.0" --show-bin-path)")
  done
  BIN_DIR="${BIN_DIRS[0]}"
else
  swift build -c release --product "$EXECUTABLE"
  BIN_DIR="$(swift build -c release --show-bin-path)"
fi

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
if [[ "${UNIVERSAL:-0}" == 1 ]]; then
  lipo -create -output "$APP/Contents/MacOS/Welp" "${BIN_DIRS[@]/%//$EXECUTABLE}"
else
  cp "$BIN_DIR/$EXECUTABLE" "$APP/Contents/MacOS/Welp"
fi
cp Support/Info.plist "$APP/Contents/Info.plist"
# App icon from the Icon Composer file: Assets.car carries the Liquid Glass icon for macOS 26
# and later, AppIcon.icns the flat one for older systems. Needs Xcode 26's actool; without it,
# fall back to the prebuilt icns (made from the same file). Older actools succeed without
# writing anything, so check for the icon rather than the exit status.
xcrun actool Support/AppIcon.icon --compile "$APP/Contents/Resources" \
  --app-icon AppIcon --platform macosx --target-device mac \
  --minimum-deployment-target 14.0 --development-region en \
  --enable-on-demand-resources NO \
  --output-partial-info-plist "build/AppIcon.partial.plist" >/dev/null || true
if [[ ! -f "$APP/Contents/Resources/AppIcon.icns" ]]; then
  echo "warning: actool could not compile Support/AppIcon.icon; using Support/AppIcon.icns" >&2
  cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi
# Translations (compiled String Catalogs). Must live in Contents/Resources: code signing
# rejects files in the bundle root, where SwiftPM's generated accessor would look.
for BUNDLE in "${BUNDLES[@]}"; do
  cp -R "$BIN_DIR/$BUNDLE" "$APP/Contents/Resources/"
  rm -f "$APP/Contents/Resources/$BUNDLE/Localizable.xcstrings"  # Source, not needed.
done

PLIST="$APP/Contents/Info.plist"
if [[ "$EXECUTABLE" == WelpPro ]]; then
  # Updates (Sparkle) are for the official app only; builds of the core don't update into it.
  # The feed redirects to the appcast of the latest release; updates are signed with the
  # EdDSA key whose public half is below (private half: Keychain, see scripts/release.sh).
  mkdir -p "$APP/Contents/Frameworks"
  cp -R "$BIN_DIR/Sparkle.framework" "$APP/Contents/Frameworks/"
  # Sparkle's XPC services are only needed by sandboxed apps; Welp isn't sandboxed.
  rm -rf "$APP/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices" \
    "$APP/Contents/Frameworks/Sparkle.framework/XPCServices"
  plutil -replace SUFeedURL -string "https://www.getwelp.io/appcast.xml" "$PLIST"
  plutil -replace SUPublicEDKey -string "FEDmj9cU8PzbyuGV4imDIUB+EAnFouyaV5DfHLp83u4=" "$PLIST"
  plutil -replace SUEnableSystemProfiling -bool NO "$PLIST"
fi
if [[ -n "${VERSION:-}" ]]; then
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$PLIST"
fi
if [[ -n "${BUILD_NUMBER:-}" ]]; then
  plutil -replace CFBundleVersion -string "$BUILD_NUMBER" "$PLIST"
fi

# Developer ID first, whatever order the keychain lists them in: a build signed with another
# identity loses the Accessibility permission granted to the previous one.
IDENTITIES="$(security find-identity -v -p codesigning)"
IDENTITY="${CODESIGN_IDENTITY:-$(awk -F'"' '/Developer ID Application/ { print $2; exit }' \
  <<<"$IDENTITIES")}"
IDENTITY="${IDENTITY:-$(awk -F'"' '/Apple Development/ { print $2; exit }' <<<"$IDENTITIES")}"
if [[ -z "$IDENTITY" ]]; then
  echo "warning: no signing identity found; using ad-hoc signing" >&2
  IDENTITY="-"
fi
# Notarization requires a secure timestamp; other builds skip it so they work offline.
TIMESTAMP="--timestamp=none"
if [[ "$IDENTITY" == *"Developer ID Application"* ]]; then
  TIMESTAMP="--timestamp"
fi
# Inside out and without --deep, as Sparkle documents: its helpers, the framework, the app.
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE" ]]; then
  for CODE in "$SPARKLE/Versions/B/Autoupdate" "$SPARKLE/Versions/B/Updater.app" "$SPARKLE"; do
    codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$CODE"
  done
fi
codesign --force --options runtime "$TIMESTAMP" --sign "$IDENTITY" "$APP"

echo "Built $APP ($EXECUTABLE, signed with: $IDENTITY)"
