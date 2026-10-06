
#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-7050}"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

if command -v lsof >/dev/null 2>&1 && lsof -i ":${PORT}" >/dev/null 2>&1; then
  echo "! Port ${PORT} occupé — libération…"
  lsof -ti ":${PORT}" | xargs -r kill -9 2>/dev/null || true
  sleep 1
fi

echo "-> Serveur : http://localhost:${PORT}"
exec python3 -m http.server "${PORT}" --bind 127.0.0.1
