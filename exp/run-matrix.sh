#!/usr/bin/env bash
# Interleaved cold-build matrix: source, prebuilt, source, prebuilt, ...
#
#   run-matrix.sh <name> <app-dir> <repo-dir> <libs> <runs> [tasks]
#
# Interleaving cancels out machine drift (thermals, background load).
set -uo pipefail
W="$(cd "$(dirname "$0")/.." && pwd)"
NAME="$1"; APP="$2"; REPO="$3"; LIBS="$4"; RUNS="$5"
export TASKS="${6:-:app:assembleDebug}"
export PREBUILT_REPO="$REPO" PREBUILT_LIBS="$LIBS"
LOG="$W/exp/results/$NAME.matrix.log"; : > "$LOG"

settle() { sleep 20; }   # let the previous daemon / disk writeback quiet down; not part of any timed region
for i in $(seq 1 "$RUNS"); do
  for mode in source prebuilt; do
    settle
    "$W/exp/cold-build.sh" "$NAME-$mode-r$i" "$APP" "$mode" >>"$LOG" 2>&1 || echo "[matrix] $NAME-$mode-r$i FAILED" >>"$LOG"
  done
done
echo "[matrix] $NAME finished" >>"$LOG"
