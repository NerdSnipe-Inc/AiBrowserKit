#!/usr/bin/env bash
# Run AiBrowserKit unit or integration tests via swift test.
# Usage: scripts/ci-test.sh [unit|integration]
set -euo pipefail

MODE="${1:-unit}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if [[ -x "${DEVELOPER_DIR:-}/usr/bin/swift" ]]; then
  :
elif [[ -x "${HOME}/Applications/Xcode-beta.app/Contents/Developer/usr/bin/swift" ]]; then
  export DEVELOPER_DIR="${HOME}/Applications/Xcode-beta.app/Contents/Developer"
fi

cd "$ROOT"

bash scripts/check-no-cursor-attribution.sh

case "$MODE" in
  unit)
    swift test
    ;;
  integration)
    RUN_INTEGRATION_TESTS=1 swift test
    ;;
  policy)
    bash scripts/check-no-cursor-attribution.sh
    ;;
  *)
    echo "Usage: $0 [unit|integration|policy]" >&2
    exit 2
    ;;
esac
