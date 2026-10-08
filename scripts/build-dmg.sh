#!/usr/bin/env bash
# Packs an app into a DMG with Welp's install window: the background from Support/DMG and
# the app next to an Applications link to drag it onto. Unsigned; release.sh signs it.
#
#   scripts/build-dmg.sh <app> <volume-name> <output.dmg>
#
# Installs dmgbuild (pinned in Support/DMG/requirements.txt) into build/dmgbuild once.
set -euo pipefail
cd "$(dirname "$0")/.."

APP="${1:?usage: scripts/build-dmg.sh <app> <volume-name> <output.dmg>}"
VOLUME="${2:?usage: scripts/build-dmg.sh <app> <volume-name> <output.dmg>}"
DMG="${3:?usage: scripts/build-dmg.sh <app> <volume-name> <output.dmg>}"

VENV="build/dmgbuild"
if [[ ! -x "$VENV/bin/dmgbuild" ]]; then
  python3 -m venv "$VENV"
  "$VENV/bin/pip" install --quiet --require-hashes -r Support/DMG/requirements.txt
fi

rm -f "$DMG"
"$VENV/bin/dmgbuild" -s Support/DMG/settings.py \
  -D app="$APP" -D background=Support/DMG/background.png "$VOLUME" "$DMG"
