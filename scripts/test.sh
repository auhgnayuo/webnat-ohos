#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
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
python3 contracts/verify.py
report='library/.test/default/intermediates/test/coverage_data/test_result.txt'
rm -f "$report"
"$runner" --mode module -p module=library@default -p product=default test --no-daemon "$@"
# Hvigor can exit successfully even when Hypium cases fail or time out.
python3 - "$report" <<'PY'
import collections, pathlib, sys
path = pathlib.Path(sys.argv[1])
if not path.exists():
    sys.exit('Missing Hypium report; tests were not verified')
results = collections.Counter(line[len('result='):] for line in path.read_text().splitlines() if line.startswith('result='))
print('Hypium:', dict(results))
if not results or any(name != 'Success' for name in results):
    sys.exit('Hypium tests did not all pass')
PY
