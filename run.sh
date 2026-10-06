#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-7050}"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

echo "-> Agrégation…"
if ! python scripts/aggregate.py --pages "${PAGES:-3}"; then
  echo "! API injoignable -> fallback seed"
  python scripts/seed_car_jaune.py
fi

echo "-> Serveur : http://localhost:${PORT}"
exec python -m http.server "${PORT}" --bind 127.0.0.1
