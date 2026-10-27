#!/usr/bin/env bash
# Stage 1 (one runner): fill the dependency store, then compile + publish the libs as AARs.
# The dependency store (modules-2 + gradle wrapper) is cached for the timed jobs; the AARs are an artifact.
#
#   ci-prebuild.sh <mmkv|vc>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${1:?usage: ci-prebuild.sh <mmkv|vc>}"
# shellcheck source=config.sh
source "$ROOT/config.sh" "$APP"
export GRADLE_USER_HOME="$ROOT/exp/gradle-home"
RES="$ROOT/exp/results"; mkdir -p "$RES"

echo "$(sysctl -n machdep.cpu.brand_string) | $(sysctl -n hw.ncpu) cores | $(( $(sysctl -n hw.memsize) / 1073741824 )) GB | macOS $(sw_vers -productVersion)" | tee "$RES/host-prebuild.txt"

"$ROOT/setup.sh" "$APP"

# Warm-up (untimed, not reported): a full build so every dependency of the app is in modules-2.
"$ROOT/exp/cold-build.sh" "warmup-$APP" "$APP_DIR" source

# Prebuild: delete the libs' own outputs, then compile + publish them. Reported as the one-time cost.
node "$ROOT/exp/libdirs.js" "$APP_DIR" | while IFS= read -r d; do rm -rf "$d/build" "$d/.cxx"; done
T0=$(date +%s)
"$ROOT/exp/publish.sh" "$APP_DIR" "$ROOT/exp/maven-repo" arm64-v8a "$LIBS"
echo "$(( $(date +%s) - T0 ))" > "$RES/$APP.prebuild-seconds.txt"
echo "[prebuild] done in $(cat "$RES/$APP.prebuild-seconds.txt")s"
