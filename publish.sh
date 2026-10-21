#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ "${1:-}" != "" && "${1:-}" != "--build-only" ]]; then
  echo "Usage: $0 [--build-only]" >&2; exit 2
fi
if [[ -z "${NODE_HOME:-}" && -d '/Applications/DevEco-Studio.app/Contents/tools/node' ]]; then
  export NODE_HOME='/Applications/DevEco-Studio.app/Contents/tools/node'
fi
if [[ -n "${HVIGORW:-}" ]]; then
  runner="$HVIGORW"
elif command -v hvigorw >/dev/null 2>&1; then
  runner=hvigorw
else
  runner='/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw'
fi
HAR_PATH='library/build/default/outputs/default/library.har'
VERSION=$(python3 - <<'PY'
import json
with open('library/oh-package.json5') as f: print(json.load(f)['version'])
PY
)
echo "=== Webnat OHPM release preparation: $VERSION ==="
./scripts/test.sh
"$runner" --mode module -p module=library@default -p product=default assembleHar --no-daemon
[[ -f "$HAR_PATH" ]] || { echo "Missing HAR: $HAR_PATH" >&2; exit 1; }
if [[ "${1:-}" == '--build-only' ]]; then
  echo "Built $HAR_PATH for $VERSION; nothing published."
  exit 0
fi
read -r -p "Publish webnat@$VERSION to OHPM? (y/N) " confirm
[[ "$confirm" == y || "$confirm" == Y ]] || { echo 'Cancelled.'; exit 0; }
ohpm publish "$HAR_PATH"
echo "Submitted webnat@$VERSION to OHPM; confirm registry validation and availability."
