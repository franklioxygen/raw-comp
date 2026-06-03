#!/usr/bin/env bash
# Pre-merge verification for the comparison-adjustments feature.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "==> Swift build"
swift build

echo "==> Swift tests"
TEST_LOG="$(mktemp)"
swift test 2>&1 | tee "$TEST_LOG"
PASSED="$(grep -E 'Test run with [0-9]+ tests' "$TEST_LOG" | tail -1 | grep -oE '[0-9]+' | head -1 || true)"
rm -f "$TEST_LOG"
EXPECTED=39
if [[ -z "${PASSED:-}" || "$PASSED" != "$EXPECTED" ]]; then
  echo "ERROR: expected $EXPECTED passing tests, got '${PASSED:-unknown}'"
  exit 1
fi
echo "    ($PASSED tests passed)"

echo "==> Localization parity"
python3 scripts/check_l10n.py

echo "==> All checks passed"
