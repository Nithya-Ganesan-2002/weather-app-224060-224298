#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/weather-app-224060-224298/FrontendApplication"
cd "$WS"
# allow scaffold only when directory is empty except optional .git
if find "$WS" -mindepth 1 -maxdepth 1 -not -name '.git' -print -quit | read; then echo "SKIP_SCAFFOLD_NON_EMPTY"; exit 0; fi
# detect TS preference: env override or existing repo files (rare for empty)
USE_TS=0
if [ "${USE_TYPESCRIPT:-0}" = "1" ]; then USE_TS=1; elif find "$WS" -type f -name '*.ts' -print -quit | read; then USE_TS=1; fi
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR" || true; }
trap cleanup EXIT
# prefer global create-react-app
if command -v create-react-app >/dev/null 2>&1; then
  if [ "$USE_TS" -eq 1 ]; then
    create-react-app "$TMPDIR" --template typescript --use-npm --yes --silent --no-analytics
  else
    create-react-app "$TMPDIR" --use-npm --yes --silent --no-analytics
  fi
fi
# fallback to npx create-react-app@latest
if [ ! -f "$TMPDIR/package.json" ]; then
  if command -v npx >/dev/null 2>&1; then
    if [ "$USE_TS" -eq 1 ]; then
      npx create-react-app@latest "$TMPDIR" --template typescript --use-npm --yes --silent --no-analytics
    else
      npx create-react-app@latest "$TMPDIR" --use-npm --yes --silent --no-analytics
    fi
  fi
fi
# final fallback to Vite
if [ ! -f "$TMPDIR/package.json" ]; then
  if command -v npm >/dev/null 2>&1; then
    if [ "$USE_TS" -eq 1 ]; then
      npm init vite@latest "$TMPDIR" -- --template react-ts --yes --silent
    else
      npm init vite@latest "$TMPDIR" -- --template react --yes --silent
    fi
    (cd "$TMPDIR" && npm i --no-audit --no-fund --loglevel=error) || true
  fi
fi
# verify package.json then move into place atomically
if [ ! -f "$TMPDIR/package.json" ]; then
  rm -rf "$TMPDIR" || true
  echo "ERR_SCAFFOLD_FAILED" >&2
  exit 20
fi
# create minimal .env inside TMPDIR
cat > "$TMPDIR/.env" <<EOF
REACT_APP_API_URL=http://localhost:8000
EOF
# move contents into workspace
shopt -s dotglob
# Ensure we don't clobber anything unexpectedly; workspace is empty by earlier check
mv "$TMPDIR"/* "$WS"/ || true
# clean up handled by trap
exit 0
