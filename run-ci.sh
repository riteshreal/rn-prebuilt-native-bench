#!/usr/bin/env bash
# One app, end to end: setup -> warm-up -> prebuild AARs -> interleaved cold matrix -> report.
# Works on any Mac with JDK 17, Node, Bun and the Android SDK (NDK 29.0.14206865, CMake 3.22.1).
#
#   run-ci.sh <mmkv|vc> [pairs=2]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${1:?usage: run-ci.sh <mmkv|vc> [pairs]}"; RUNS="${2:-2}"
# shellcheck source=config.sh
source "$ROOT/config.sh" "$APP"
export GRADLE_USER_HOME="$ROOT/exp/gradle-home"
RES="$ROOT/exp/results"; mkdir -p "$RES"

{
  echo "host: $(sysctl -n machdep.cpu.brand_string) | $(sysctl -n hw.ncpu) cores | $(( $(sysctl -n hw.memsize) / 1073741824 )) GB RAM | macOS $(sw_vers -productVersion)"
  echo "app: $APP | pairs per mode: $RUNS | abis: arm64-v8a | task: :app:assembleDebug"
} | tee "$RES/$APP.host.txt"

"$ROOT/setup.sh" "$APP"

# 1. Warm-up (untimed, not reported): fills the dependency store (modules-2) so the timed runs are not network-bound.
"$ROOT/exp/cold-build.sh" "warmup-$APP" "$APP_DIR" source

# 2. Prebuild: delete the libs' own outputs, then compile + publish them as AARs. Reported as the one-time cost.
node "$ROOT/exp/libdirs.js" "$APP_DIR" | while IFS= read -r d; do rm -rf "$d/build" "$d/.cxx"; done
T0=$(date +%s)
"$ROOT/exp/publish.sh" "$APP_DIR" "$ROOT/exp/maven-repo" arm64-v8a "$LIBS"
echo "$(( $(date +%s) - T0 ))" > "$RES/$APP.prebuild-seconds.txt"

# 3. Interleaved cold matrix: source, prebuilt, source, prebuilt, ...
"$ROOT/exp/run-matrix.sh" "$APP" "$APP_DIR" "$ROOT/exp/maven-repo" "$LIBS" "$RUNS"

# 4. Report
python3 -I "$ROOT/exp/report.py" "$RES" "$APP" | tee "$RES/$APP.report.txt"
if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### $APP"; echo '```'; cat "$RES/$APP.host.txt" "$RES/$APP.report.txt"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
fi
