#!/usr/bin/env bash
# Clone the repos at the exact commits used in the local experiment, install JS deps,
# and point the app at the cloned nitro (instead of the npm copy).
#
#   setup.sh <mmkv|vc>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
R="$ROOT/repos"; mkdir -p "$R"

NITRO_SHA=fb894f673ff04bb392fbe6037ead4881cc0a9bc2
MMKV_SHA=ca5acf0ca9acc5cd1b75c486be6adad40c488047
VC_SHA=1a69f290e1a4308d3fb9bec0a02acb55355005a8

fetch() { # <dir> <url> <sha>
  [ -d "$R/$1/.git" ] || git init -q "$R/$1"
  git -C "$R/$1" fetch -q --depth 1 "$2" "$3"
  git -C "$R/$1" checkout -q --force FETCH_HEAD
}

fetch nitro https://github.com/mrousavy/nitro.git "$NITRO_SHA"
case "${1:-}" in
  mmkv) fetch mmkv https://github.com/mrousavy/react-native-mmkv.git "$MMKV_SHA"; APPREPO=mmkv ;;
  vc)   fetch vision-camera https://github.com/mrousavy/react-native-vision-camera.git "$VC_SHA"; APPREPO=vision-camera ;;
  *) echo "usage: setup.sh <mmkv|vc>" >&2; exit 2 ;;
esac

(cd "$R/nitro" && bun install)
(cd "$R/$APPREPO" && bun install)

P="$R/$APPREPO/node_modules/react-native-nitro-modules"
if [ ! -L "$P" ]; then
  mv "$P" "$P.npm-orig"
  ln -s "$R/nitro/packages/react-native-nitro-modules" "$P"
fi
echo "[setup] $APPREPO @ $(git -C "$R/$APPREPO" rev-parse --short HEAD), nitro @ $(git -C "$R/nitro" rev-parse --short HEAD)"
