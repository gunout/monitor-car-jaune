#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

echo "-> Téléchargement du GTFS…"
python3 scripts/fetch_car_jaune.py || exit 1
echo "-> Parsing du GTFS…"
python3 scripts/parse_car_jaune_full.py || exit 1
echo "OK Données à jour"


