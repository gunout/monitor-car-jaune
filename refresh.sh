
#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${BASE_DIR}/logs/aggregate.log"
mkdir -p "$(dirname "${LOG}")"
[[ -d "${BASE_DIR}/.venv" ]] && source "${BASE_DIR}/.venv/bin/activate" 2>/dev/null || true
{
  echo "---- $(date -Is) ----"
  python3 "${BASE_DIR}/scripts/fetch_car_jaune.py" 2>&1 || echo "! fetch échoué"
  python3 "${BASE_DIR}/scripts/parse_car_jaune_full.py" 2>&1 || echo "! parse échoué"
} >> "${LOG}" 2>&1


