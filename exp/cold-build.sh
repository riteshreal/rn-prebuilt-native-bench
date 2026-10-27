#!/usr/bin/env bash
# Cold (no-cache) Gradle build of an RN example app, optionally consuming prebuilt AARs.
#
#   cold-build.sh <label> <app-dir> <mode> [extra gradle args...]
#
#   <app-dir>  the RN app root (contains android/), e.g. repos/mmkv/example
#   <mode>     source   : every library is compiled from source
#              prebuilt : libs in $PREBUILT_LIBS come from the AAR repo in $PREBUILT_REPO
#
# "Cold" means, before the timed run:
#   * Gradle daemons of THIS experiment's GRADLE_USER_HOME are stopped (other daemons are untouched)
#   * everything in the experiment's gradle home is deleted except the downloaded-dependency store
#     (modules-2) and the wrapper distribution  -> no build cache, transforms, kotlin-dsl, file hashes
#   * build/, .cxx/ and .gradle/ of the app and of every autolinked library are deleted
#   * --no-build-cache --no-configuration-cache, Kotlin compiled in-process (no shared Kotlin daemon)
#   * no ccache installed
set -euo pipefail

W="$(cd "$(dirname "$0")/.." && pwd)"
EXP="$W/exp"
LABEL="$1"; APP="$2"; MODE="$3"; shift 3
EXTRA=("$@")

export GRADLE_USER_HOME="${GRADLE_USER_HOME:-$EXP/gradle-home}"
export EXP_TASK_TIMES="$EXP/results/$LABEL.times.csv"
PREBUILT_REPO="${PREBUILT_REPO:-$EXP/maven-repo}"
PREBUILT_LIBS="${PREBUILT_LIBS:-}"
TASKS="${TASKS:-:app:assembleDebug}"
ABIS="${ABIS:-arm64-v8a}"

mkdir -p "$EXP/results"
: > "$EXP_TASK_TIMES"
cd "$APP/android"

echo "[cold] label=$LABEL mode=$MODE tasks=$TASKS abis=$ABIS"
echo "[cold] load before: $(uptime | sed 's/.*load averages*: //')"

# 1. stop only our own daemons
./gradlew --stop >/dev/null 2>&1 || true

# 2. wipe all gradle-home state except the dependency store + wrapper dists
if [ -d "$GRADLE_USER_HOME/caches" ]; then
  find "$GRADLE_USER_HOME/caches" -mindepth 1 -maxdepth 1 ! -name modules-2 -exec rm -rf {} +
fi
rm -rf "$GRADLE_USER_HOME/daemon" "$GRADLE_USER_HOME/native" "$GRADLE_USER_HOME/.tmp" 2>/dev/null || true

# 3. wipe project build outputs (app + every autolinked lib, resolved through symlinks)
node "$EXP/libdirs.js" "$APP" | while IFS= read -r d; do
  rm -rf "$d/build" "$d/.cxx" "$d/.gradle"
done
rm -rf build .gradle app/build app/.cxx

ARGS=(
  "$TASKS"
  -PreactNativeArchitectures="$ABIS"
  --no-build-cache --no-configuration-cache
  -Pkotlin.compiler.execution.strategy=in-process
  -Dorg.gradle.jvmargs="-Xmx4g -XX:MaxMetaspaceSize=1g"
  --console=plain
  -I "$EXP/init/exp.init.gradle"
  -PprebuiltLibs="$PREBUILT_LIBS"
)
if [ "$MODE" = "prebuilt" ]; then
  ARGS+=(-PprebuiltConsume="$PREBUILT_REPO")
fi
ARGS+=("${EXTRA[@]+"${EXTRA[@]}"}")

START=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
set +e
./gradlew "${ARGS[@]}" >"$EXP/results/$LABEL.log" 2>&1
RC=$?
set -e
END=$(perl -MTime::HiRes=time -e 'printf "%.3f", time')
WALL=$(perl -e "printf '%.1f', $END - $START")

./gradlew --stop >/dev/null 2>&1 || true

echo "$LABEL,$MODE,$WALL,$RC" | tee -a "$EXP/results/summary.csv"
echo "[cold] done label=$LABEL wall=${WALL}s exit=$RC  (log: exp/results/$LABEL.log)"
exit $RC
