#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${BASE_DIR}/logs/aggregate.log"
mkdir -p "$(dirname "${LOG}")"
[[ -d "${BASE_DIR}/.venv" ]] && source "${BASE_DIR}/.venv/bin/activate" 2>/dev/null || true
{
  echo "---- $(date -Is) ----"
  if ! python "${BASE_DIR}/scripts/aggregate.py" --pages "${PAGES:-3}"; then
    echo "! fallback seed"
    python "${BASE_DIR}/scripts/seed_car_jaune.py"
  fi
} >> "${LOG}" 2>&1
