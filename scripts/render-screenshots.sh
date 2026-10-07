#!/usr/bin/env bash
# Renders the settings window with sample data into docs/images, in every app language:
# English (the README) in docs/images, other languages in docs/images/<language>.
#
# The debug binary is wrapped in a minimal .app, because macOS only picks a localization
# for bundled apps (Info.plist `CFBundleLocalizations`).
set -euo pipefail
cd "$(dirname "$0")/.."

swift build
BIN_DIR="$(swift build --show-bin-path)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

APP="$WORK/Welp.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Welp" "$APP/Contents/MacOS/Welp"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp -R "$BIN_DIR/Welp_WelpApp.bundle" "$APP/Contents/Resources/"

# The images the READMEs use; the renderer produces every pane in light and dark.
IMAGES=(chats-light chats-dark behavior-light appearance-light)

for language in $(plutil -extract CFBundleLocalizations json -o - Support/Info.plist | tr -d '[]"' | tr ',' ' '); do
  "$APP/Contents/MacOS/Welp" --render-settings "$WORK/$language" -AppleLanguages "($language)"
  target="docs/images"
  [[ "$language" == en ]] || target="docs/images/$language"
  mkdir -p "$target"
  for image in "${IMAGES[@]}"; do
    cp "$WORK/$language/$image.png" "$target/$image.png"
  done
  echo "Rendered $language → $target"
done
