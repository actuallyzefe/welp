#!/usr/bin/env bash
# Builds a universal, Developer ID signed, notarized and stapled Welp-<version>.dmg in ./build.
#
#   scripts/release.sh 1.0.0 [build-number]
#
# Needs release notes in docs/releases/<version>.md: Sparkle shows them in the update window
# and the release workflow uses them for the GitHub release.
#
# Notarization credentials, either:
#   NOTARY_PROFILE=welp (default)   a keychain profile created once with
#                                   `xcrun notarytool store-credentials welp ...`
#   or, in CI, an App Store Connect API key:
#   NOTARY_KEY_PATH, NOTARY_KEY_ID, NOTARY_ISSUER
# Set SKIP_NOTARIZE=1 to stop after signing (to check the build without uploading it).
#
# Also writes build/appcast.xml, the Sparkle feed for this release, signed with the EdDSA key
# in the Keychain (created once with Sparkle's generate_keys) or SPARKLE_KEY_FILE in CI.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:?usage: scripts/release.sh <version> [build-number]}"
VERSION="${VERSION#v}"
if [[ ! "$VERSION" =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  echo "error: version must look like 1.2.3, got '$VERSION'" >&2
  exit 1
fi
# CFBundleVersion, which Sparkle compares to find newer versions: derived from the version
# (1.2.3 → 1002003), so it always grows with it and doesn't depend on the git history.
MAJOR=$((10#${BASH_REMATCH[1]})) MINOR=$((10#${BASH_REMATCH[2]})) PATCH=$((10#${BASH_REMATCH[3]}))
if ((MINOR > 999 || PATCH > 999)); then
  echo "error: minor and patch versions must be below 1000" >&2
  exit 1
fi
BUILD_NUMBER="${2:-$((MAJOR * 1000000 + MINOR * 1000 + PATCH))}"

NOTES="docs/releases/$VERSION.md"
if [[ ! -f "$NOTES" ]]; then
  echo "error: write the release notes in $NOTES first." >&2
  exit 1
fi

IDENTITY="${CODESIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/ { print $2; exit }')}"
if [[ "$IDENTITY" != *"Developer ID Application"* ]]; then
  echo "error: a 'Developer ID Application' certificate is required to publish a release." >&2
  echo "Create one in Xcode → Settings → Accounts → Manage Certificates." >&2
  exit 1
fi

notarize() {
  if [[ -n "${NOTARY_KEY_PATH:-}" ]]; then
    xcrun notarytool submit "$1" --wait \
      --key "$NOTARY_KEY_PATH" --key-id "${NOTARY_KEY_ID:?}" --issuer "${NOTARY_ISSUER:?}"
  else
    xcrun notarytool submit "$1" --wait --keychain-profile "${NOTARY_PROFILE:-welp}"
  fi
}

UNIVERSAL=1 VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" CODESIGN_IDENTITY="$IDENTITY" \
  scripts/build-app.sh

APP="build/Welp.app"
codesign --verify --strict --deep --verbose=2 "$APP"
lipo "$APP/Contents/MacOS/Welp" -verify_arch arm64 x86_64

if [[ "${SKIP_NOTARIZE:-0}" != 1 ]]; then
  # Notarize and staple the app itself first, so it opens offline once copied out of the DMG.
  ZIP="$(mktemp -d)/Welp.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  xcrun stapler staple "$APP"
  spctl --assess --type execute --verbose=2 "$APP"
fi

DMG="build/Welp-$VERSION.dmg"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$DMG"
hdiutil create -volname "Welp $VERSION" -srcfolder "$STAGING" -fs HFS+ -format UDZO "$DMG"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

if [[ "${SKIP_NOTARIZE:-0}" == 1 ]]; then
  echo "Signed $DMG (not notarized: SKIP_NOTARIZE=1)"
  exit 0
fi

notarize "$DMG"
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature --verbose=2 "$DMG"

# Same file under a fixed name, so releases/latest/download/Welp.dmg always points to the
# newest release (the website's download link).
cp "$DMG" build/Welp.dmg
# Sparkle feed: one item, the DMG of this release on GitHub. getwelp.io/appcast.xml redirects
# to the appcast attached to the latest release.
SPARKLE_BIN=.build/artifacts/sparkle/Sparkle/bin
UPDATES="$(mktemp -d)"
cp "$DMG" "$UPDATES/"
cp "$NOTES" "$UPDATES/Welp-$VERSION.md"  # Same name as the archive: its release notes.
KEY_ARGS=()
if [[ -n "${SPARKLE_KEY_FILE:-}" ]]; then
  KEY_ARGS=(--ed-key-file "$SPARKLE_KEY_FILE")
fi
# ${…+…}: macOS's bash 3.2 treats an empty array as unset under `set -u`.
"$SPARKLE_BIN/generate_appcast" ${KEY_ARGS[@]+"${KEY_ARGS[@]}"} --maximum-deltas 0 --embed-release-notes \
  --link "https://www.getwelp.io" \
  --download-url-prefix "https://github.com/actuallyzefe/welp/releases/download/v$VERSION/" \
  "$UPDATES"
cp "$UPDATES/appcast.xml" build/appcast.xml
rm -rf "$UPDATES"

(cd build && shasum -a 256 "Welp-$VERSION.dmg" > "Welp-$VERSION.dmg.sha256")
echo "Released $DMG ($(cut -d' ' -f1 "build/Welp-$VERSION.dmg.sha256"))"
