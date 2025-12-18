#!/usr/bin/env bash
set -euo pipefail
WS="/home/kavia/workspace/code-generation/weather-app-224060-224298/FrontendApplication"
cd "$WS"
PORT=5000
LOG=/tmp/frontend_serve.log
# wait for listener with ss/lsof fallback
LISTEN_PID=""
for i in 0 1 2 3 4 5; do
  if command -v ss >/dev/null 2>&1; then
    LISTEN_PID=$(ss -ltnp 2>/dev/null | awk -v p=":$PORT" '$4~p{match($0,/pid=([0-9]+)/,a); if(a[1])print a[1]; exit}') || true
  elif command -v lsof >/dev/null 2>&1; then
    LISTEN_PID=$(lsof -iTCP:$PORT -sTCP:LISTEN -t 2>/dev/null || true)
  fi
  if [ -n "$LISTEN_PID" ]; then break; fi
  sleep 1
done
# fallback to pid file
if [ -z "$LISTEN_PID" ] && [ -f /tmp/frontend_serve.pid ]; then
  LISTEN_PID=$(cat /tmp/frontend_serve.pid 2>/dev/null || true)
fi
# HTTP health check with retries
HTTP=000
MAX=12
i=0
while [ $i -lt $MAX ]; do
  sleep $((i<3?1:2))
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:${PORT}/ || true)
  if [[ "$HTTP" =~ ^2[0-9][0-9]$ ]]; then break; fi
  i=$((i+1))
done
if ! [[ "$HTTP" =~ ^2[0-9][0-9]$ ]]; then echo "ERR_VALIDATION_HTTP: $HTTP; see $LOG" >&2; exit 52; fi
# write evidence
printf "%s\n" "pid=${LISTEN_PID:-unknown}" "http=$HTTP" "log=$LOG" > /tmp/frontend_validation_result.txt
# ensure server stopped by calling stop script
if [ -x ./.init/stop.sh ]; then
  bash ./.init/stop.sh || true
else
  # try direct cleanup
  if [ -n "${LISTEN_PID:-}" ] && [[ "$LISTEN_PID" =~ ^[0-9]+$ ]]; then
    kill "$LISTEN_PID" 2>/dev/null || true
    sleep 1
    if ps -p "$LISTEN_PID" >/dev/null 2>&1; then kill -9 "$LISTEN_PID" 2>/dev/null || true; fi
  fi
fi
