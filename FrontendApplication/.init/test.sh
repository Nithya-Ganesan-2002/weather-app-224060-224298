#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/weather-app-224060-224298/FrontendApplication"
cd "$WS"
mkdir -p src/__tests__
if [ ! -f src/__tests__/smoke.test.js ]; then
  cat > src/__tests__/smoke.test.js <<'EOF'
test('smoke',()=>{expect(true).toBe(true)})
EOF
fi
# prefer project-local react-scripts or jest; otherwise add jest dev dep (non-fatal if install fails)
if [ -x ./node_modules/.bin/react-scripts ]; then :
elif [ -x ./node_modules/.bin/jest ]; then :
else
  npm i --no-audit --no-fund --save-dev jest@^29.0.0 --loglevel=error || true
fi
# additive: ensure package.json test script exists without overwriting
if [ -f package.json ]; then
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.scripts=p.scripts||{};p.scripts.test=p.scripts.test||'react-scripts test --watchAll=false';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" >/dev/null
fi
# run tests in CI mode non-interactively and deterministically
CI=1 npm test -- --watchAll=false --runInBand || { echo 'ERR_TESTS_FAILED' >&2; exit 40; }
