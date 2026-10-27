#!/usr/bin/env bash
# Stage 2 (one runner per run): a single cold build, from source or from the prebuilt AARs.
# Needs the restored dependency store (exp/gradle-home) and, for `prebuilt`, the AARs in exp/maven-repo.
#
#   ci-timed.sh <mmkv|vc> <source|prebuilt> <rep>
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${1:?usage: ci-timed.sh <mmkv|vc> <source|prebuilt> <rep>}"; MODE="${2:?}"; REP="${3:?}"
# shellcheck source=config.sh
source "$ROOT/config.sh" "$APP"
export GRADLE_USER_HOME="$ROOT/exp/gradle-home"
RES="$ROOT/exp/results"; mkdir -p "$RES"
LABEL="$APP-$MODE-r$REP"

[ -d "$GRADLE_USER_HOME/caches/modules-2" ] || { echo "dependency store missing: restore the cache first" >&2; exit 1; }
if [ "$MODE" = prebuilt ]; then
  [ -n "$(find "$ROOT/exp/maven-repo" -name '*.aar' 2>/dev/null | head -1)" ] || { echo "AARs missing: download the artifact first" >&2; exit 1; }
fi

echo "$(sysctl -n machdep.cpu.brand_string) | $(sysctl -n hw.ncpu) cores | $(( $(sysctl -n hw.memsize) / 1073741824 )) GB | macOS $(sw_vers -productVersion)" | tee "$RES/host-$LABEL.txt"

"$ROOT/setup.sh" "$APP"

export PREBUILT_REPO="$ROOT/exp/maven-repo" PREBUILT_LIBS="$LIBS"
set +e
"$ROOT/exp/cold-build.sh" "$LABEL" "$APP_DIR" "$MODE"
RC=$?
set -e
# one row per job, so rows from the four jobs can be merged without clashing on summary.csv
grep "^$LABEL," "$RES/summary.csv" > "$RES/$LABEL.row.csv" || true
exit $RC
