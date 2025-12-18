#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/weather-app-224060-224298/FrontendApplication"
cd "$WS"
PORT=5000
LOG=/tmp/frontend_serve.log
: >"$LOG"
# choose serve: prefer global then project-local
if command -v serve >/dev/null 2>&1; then SERVE_BIN=$(command -v serve); SERVE_ARGS=("-s" "build" "-l" "$PORT");
elif [ -x ./node_modules/.bin/serve ]; then SERVE_BIN="./node_modules/.bin/serve"; SERVE_ARGS=("-s" "build" "-l" "$PORT");
else echo 'ERR_SERVE_MISSING' >&2; exit 51; fi
# start serve in foreground and capture PID; ensure log capture
"$SERVE_BIN" "${SERVE_ARGS[@]}" >"$LOG" 2>&1 &
SERVE_PID=$!
# write PID file for stop script
printf "%d\n" "$SERVE_PID" >/tmp/frontend_serve.pid
# install cleanup trap to ensure stop on exit
_cleanup() {
  if [ -n "${SERVE_PID:-}" ] && [[ "$SERVE_PID" =~ ^[0-9]+$ ]]; then
    kill "$SERVE_PID" 2>/dev/null || true
    wait "$SERVE_PID" 2>/dev/null || true
  fi
}
trap _cleanup EXIT INT TERM
# give control back (foreground server is backgrounded above)
printf "started pid=%s log=%s\n" "$SERVE_PID" "$LOG"
