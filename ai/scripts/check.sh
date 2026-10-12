#!/usr/bin/env bash
# Usage: ai/scripts/check.sh [test/foo_test.dart ...]
set -euo pipefail
project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$project_root"

if [[ -n "${FLUTTER_BIN:-}" ]]; then
  flutter_bin="$FLUTTER_BIN"
elif command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(command -v flutter)"
elif [[ -x "$HOME/fvm/versions/3.47.5/bin/flutter" ]]; then
  flutter_bin="$HOME/fvm/versions/3.47.5/bin/flutter"
else
  echo 'Flutter unavailable. Set FLUTTER_BIN to your Flutter executable.' >&2
  exit 1
fi

dart_bin="$(dirname "$flutter_bin")/dart"
if [[ ! -x "$dart_bin" ]]; then
  echo 'Dart executable must sit alongside FLUTTER_BIN.' >&2
  exit 1
fi
"$dart_bin" format --output=none --set-exit-if-changed lib test integration_test
"$flutter_bin" analyze
if [[ "$#" -eq 0 ]]; then
  "$flutter_bin" test
else
  "$flutter_bin" test "$@"
fi
