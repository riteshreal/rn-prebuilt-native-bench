#!/usr/bin/env bash
# publish.sh <app-dir> <repo-dir> <abis> <comma-separated libs>   (publishes the debug variant of each lib as an AAR)
set -euo pipefail
W="$(cd "$(dirname "$0")/.." && pwd)"
APP="$1"; REPO="$2"; ABIS="$3"; LIBS="$4"
export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$W/exp/gradle-home}"
rm -rf "$REPO"
TASKS=(); IFS=',' read -ra L <<<"$LIBS"; for l in "${L[@]}"; do TASKS+=(":$l:publishDebugPublicationToPrebuiltRepository"); done
cd "$APP/android"
START=$(date +%s)
./gradlew "${TASKS[@]}" -PreactNativeArchitectures="$ABIS" -Pkotlin.compiler.execution.strategy=in-process \
  -Dorg.gradle.jvmargs="-Xmx4g -XX:MaxMetaspaceSize=1g" --console=plain \
  -I "$W/exp/init/exp.init.gradle" -PprebuiltLibs="$LIBS" -PprebuiltPublish="$REPO" 2>&1 | grep -E "^BUILD|FAILURE|What went wrong|error:|Could not" -A4 || true
echo "publish took $(( $(date +%s) - START ))s"
./gradlew --stop >/dev/null 2>&1 || true
echo "--- published AARs:"; find "$REPO" -name '*.aar' | while read -r a; do printf '%6s  %s\n' "$(du -h "$a" | cut -f1)" "${a#$REPO/}"; done
[ "$(find "$REPO" -name '*.aar' | wc -l | tr -d ' ')" -eq "${#L[@]}" ] || { echo "publish failed: expected ${#L[@]} AARs" >&2; exit 1; }
