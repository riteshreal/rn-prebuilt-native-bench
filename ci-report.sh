#!/usr/bin/env bash
# Stage 3: merge the per-job results and report. Fails unless every mode has the expected number of valid runs.
#
#   ci-report.sh <mmkv|vc> [reps-per-mode=2]
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="${1:?usage: ci-report.sh <mmkv|vc> [reps]}"; REPS="${2:-2}"
RES="$ROOT/exp/results"

cat "$RES"/*.row.csv > "$RES/summary.csv" 2>/dev/null || { echo "ERROR: no run results found in $RES" >&2; exit 1; }

{
  echo "runners:"; cat "$RES"/host-*.txt | sort | uniq -c | sed 's/^/  /'
  echo
  python3 -I "$ROOT/exp/report.py" "$RES" "$APP"
} | tee "$RES/$APP.report.txt"

if [ -n "${GITHUB_STEP_SUMMARY:-}" ]; then
  { echo "### $APP"; echo '```'; cat "$RES/$APP.report.txt"; echo '```'; } >> "$GITHUB_STEP_SUMMARY"
fi

BAD=0
for mode in source prebuilt; do
  ok=$(awk -F, -v a="$APP-$mode-" '$1 ~ ("^" a) && $4 == 0' "$RES/summary.csv" | wc -l | tr -d ' ')
  if [ "$ok" -ne "$REPS" ]; then echo "ERROR: $mode has $ok valid runs, expected $REPS" >&2; BAD=1; fi
done
[ "$BAD" -eq 0 ] || exit 1
