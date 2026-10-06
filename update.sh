#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

echo "-> Tentative API data.gouv.fr…"
if python scripts/aggregate.py --pages "${PAGES:-3}"; then
  echo "OK Mise à jour API réussie"
  exit 0
fi
echo "! API injoignable -> utilisation du seed local"
python scripts/seed_car_jaune.py
