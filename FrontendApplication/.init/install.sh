#!/usr/bin/env bash
set -euo pipefail

# workspace from container info
WS="/home/kavia/workspace/code-generation/weather-app-224060-224298/FrontendApplication"
mkdir -p "$WS" && cd "$WS"
# record env versions for diagnostics
{ command -v node >/dev/null 2>&1 && node -v || echo "node_missing"; command -v npm >/dev/null 2>&1 && npm -v || echo "npm_missing"; } > /tmp/frontend_env_versions.txt
# ensure package.json exists (safe minimal)
if [ ! -f package.json ]; then
  cat > package.json <<'EOF'
{
  "name": "frontendapp",
  "version": "0.1.0",
  "private": true
}
EOF
fi

# Add missing essential deps only if absent, preserve existing constraints. Do not change devDependencies Vite if present.
node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.dependencies=p.dependencies||{};if(!('react' in p.dependencies))p.dependencies.react='^18.2.0';if(!('react-dom' in p.dependencies))p.dependencies['react-dom']='^18.2.0';if(!('react-scripts' in p.dependencies) && !(p.devDependencies && ('vite' in p.devDependencies)))p.dependencies['react-scripts']='^5.0.1';p.scripts=p.scripts||{};p.scripts.build=p.scripts.build||'react-scripts build';p.scripts.start=p.scripts.start||'react-scripts start';p.scripts.test=p.scripts.test||'react-scripts test --watchAll=false';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" >/dev/null

# Prefer global create-react-app / serve if present (preinstalled in image). Determine global npm bin path and persist environment for shells.
NGLOBAL_BIN=$(npm bin -g 2>/dev/null || true)
if [ -z "${NGLOBAL_BIN:-}" ] || [ ! -d "$NGLOBAL_BIN" ]; then NGLOBAL_BIN="/usr/local/bin"; fi
PROFILE_FILE=/etc/profile.d/node_env_frontend.sh
TS=$(date +%s)
if [ -w /etc/profile.d ] 2>/dev/null; then
  if [ -f "$PROFILE_FILE" ]; then sudo cp "$PROFILE_FILE" "${PROFILE_FILE}.bak.$TS"; fi
  sudo bash -c "cat > $PROFILE_FILE <<'EOF'
export NODE_ENV=development
export PATH=$NGLOBAL_BIN:\$PATH
EOF
"
fi

# Quick network probe for npm
if command -v npm >/dev/null 2>&1; then
  if ! npm ping >/dev/null 2>&1; then echo "WARN_NETWORK_NPM" >&2; fi
fi

# Install: prefer npm ci when package-lock.json present
if [ -f package-lock.json ]; then
  npm ci --no-audit --no-fund --loglevel=error || { echo "ERR_NPM_CI" >&2; exit 30; }
else
  npm i --no-audit --no-fund --loglevel=error || { echo "ERR_NPM_INSTALL" >&2; exit 31; }
fi

# Prefer global serve binary; if absent, add serve to package.json devDependencies and persistently install locally
if command -v serve >/dev/null 2>&1; then
  echo "USING_GLOBAL_SERVE" >/tmp/frontend_serve_choice.txt
else
  # add serve to package.json devDependencies only if absent
  node -e "const fs=require('fs');const p=JSON.parse(fs.readFileSync('package.json'));p.devDependencies=p.devDependencies||{};if(!('serve' in p.devDependencies))p.devDependencies.serve='^14.1.1';fs.writeFileSync('package.json',JSON.stringify(p,null,2));" >/dev/null
  # install updated package.json deps persistently
  npm i --no-audit --no-fund --loglevel=error || true
  echo "USING_LOCAL_SERVE" >/tmp/frontend_serve_choice.txt
fi

# Post-install validation: capture installed package versions (or 'missing') and write to /tmp/frontend_pkg_versions.txt
RS_VER=$(node -e "try{console.log(require('./node_modules/react/package.json').version)}catch(e){console.log('missing')}" 2>/dev/null || true)
RDOM_VER=$(node -e "try{console.log(require('./node_modules/react-dom/package.json').version)}catch(e){console.log('missing')}" 2>/dev/null || true)
RSCRIPTS_VER=$(node -e "try{console.log(require('./node_modules/react-scripts/package.json').version)}catch(e){console.log('missing')}" 2>/dev/null || true)
printf "%s\n" "react=$RS_VER" "react-dom=$RDOM_VER" "react-scripts=$RSCRIPTS_VER" > /tmp/frontend_pkg_versions.txt

# Basic compatibility checks and exit codes
if [ "${RS_VER:-missing}" = "missing" ] || [ "${RDOM_VER:-missing}" = "missing" ]; then
  echo "ERR_MISSING_REACT" >&2
  exit 32
fi
# warn if react major not 18
case "$RS_VER" in
  18.*) ;;
  *) echo "WARN_REACT_VERSION_MISMATCH: $RS_VER" >&2 ;;
esac

# Ensure the diagnostics files reflect chosen choices
command -v npm >/dev/null 2>&1 && npm --version > /tmp/frontend_npm_version.txt || true
node -v > /tmp/frontend_node_version.txt 2>/dev/null || true

exit 0
