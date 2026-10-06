#!/usr/bin/env bash
# ============================================================
#  setup.sh — Monitor La Réunion 974  (v2 robuste)
#  Ne coupe JAMAIS : chaque étape est idempotente et
#  un fallback seed est appliqué si l'API est injoignable.
# ============================================================
set -uo pipefail

PROJECT_NAME="monitor974"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="${BASE_DIR}/.venv"
PYTHON_BIN="${PYTHON_BIN:-python3}"
PORT="${PORT:-8000}"
LOG_FILE="${BASE_DIR}/logs/setup.log"

C_RESET=$'\033[0m'; C_BLUE=$'\033[1;34m'; C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_DIM=$'\033[2m'

mkdir -p "${BASE_DIR}/logs" 2>/dev/null || true
: > "${LOG_FILE}" 2>/dev/null || true

_log_raw() { printf '%s\n' "$*" >> "${LOG_FILE}" 2>/dev/null || true; }
log()  { printf '%s[%s]%s %s\n' "${C_BLUE}"   "$(date +%H:%M:%S)" "${C_RESET}" "$*"; _log_raw "[INFO]  $*"; }
ok()   { printf '%s✓%s %s\n'    "${C_GREEN}"  "${C_RESET}"       "$*"; _log_raw "[OK]    $*"; }
warn() { printf '%s!%s %s\n'    "${C_YELLOW}" "${C_RESET}"       "$*"; _log_raw "[WARN]  $*"; }
err()  { printf '%s✗%s %s\n'    "${C_RED}"    "${C_RESET}"       "$*" >&2; _log_raw "[ERR]   $*"; }

banner() {
  cat <<'EOF'
  ┌──────────────────────────────────────────────────────────┐
  │  🇷🇪  MONITOR LA RÉUNION 974 — Installation (v2)          │
  │      Veille Open Data · data.gouv.fr · Car Jaune         │
  └──────────────────────────────────────────────────────────┘
EOF
}

check_prereqs() {
  log "Vérification des prérequis…"
  if ! command -v "${PYTHON_BIN}" >/dev/null 2>&1; then
    err "Python introuvable ('${PYTHON_BIN}')"
    err "Debian/Ubuntu : sudo apt install python3 python3-venv python3-pip"
    err "macOS         : brew install python3"
    exit 1
  fi
  local pyver
  pyver="$("${PYTHON_BIN}" -c 'import sys; print("%d.%d" % sys.version_info[:2])' 2>/dev/null || echo "?")"
  ok "Python ${pyver} détecté"
  if ! "${PYTHON_BIN}" -m venv --help >/dev/null 2>&1; then
    warn "Module 'venv' indisponible — tentative sans venv"
    return 1
  fi
  return 0
}

create_tree() {
  log "Création de l'arborescence…"
  local dirs=("${BASE_DIR}/scripts" "${BASE_DIR}/data" "${BASE_DIR}/logs")
  for d in "${dirs[@]}"; do
    mkdir -p "${d}" || { err "mkdir échoué : ${d}"; return 1; }
  done
  touch "${BASE_DIR}/data/.gitkeep" 2>/dev/null || true
  touch "${BASE_DIR}/logs/.gitkeep" 2>/dev/null || true
  ok "Arborescence prête"
  return 0
}

write_requirements() {
  log "Écriture de requirements.txt…"
  cat > "${BASE_DIR}/scripts/requirements.txt" <<'EOF'
requests>=2.31.0
EOF
  ok "requirements.txt"
}

write_aggregator() {
  log "Écriture de aggregate.py…"
  cat > "${BASE_DIR}/scripts/aggregate.py" <<'PYEOF'
#!/usr/bin/env python3
"""aggregate.py — Agrège data.gouv.fr (Réunion 974) → reunion_974_v4.json"""
from __future__ import annotations
import argparse, json, sys, time
from pathlib import Path
from typing import Any

try:
    import requests
except ImportError:
    print("X 'requests' manquant -> pip install -r scripts/requirements.txt",
          file=sys.stderr)
    sys.exit(2)

API_BASE    = "https://www.data.gouv.fr/api/1/datasets/"
DEFAULT_Q   = "réunion"
PAGE_SIZE   = 100
OUT_DEFAULT = Path(__file__).resolve().parent.parent / "data" / "reunion_974_v4.json"

REUNION_HINTS = (
    "réunion", "reunion", "974", "car jaune", "civis", "cirest",
    "cinor", "casud", "saint-denis", "saint-paul", "saint-pierre",
    "le tampon", "saint-andré",
)

def looks_like_reunion(ds):
    org = ds.get("organization") or {}
    blob = " ".join([
        str(ds.get("title", "")),
        str(ds.get("description", "") or ""),
        str(org.get("name", "")),
        " ".join(str(t.get("name", "")) for t in (ds.get("tags") or [])),
    ]).lower()
    return any(h in blob for h in REUNION_HINTS)

def normalize(ds):
    org  = ds.get("organization") or {}
    tags = ", ".join(str(t.get("name","")) for t in (ds.get("tags") or []) if t.get("name"))
    desc = (ds.get("description") or "").strip().replace("\n", " ")
    if len(desc) > 800:
        desc = desc[:797] + "..."
    return {
        "id":           ds.get("id") or ds.get("slug") or "",
        "titre":        ds.get("title") or "(sans titre)",
        "url":          ds.get("page") or f"https://www.data.gouv.fr/datasets/{ds.get('id','')}",
        "organisation": org.get("name") or org.get("acronym") or "",
        "portail":      "data.gouv.fr",
        "pays":         "FR",
        "type_api":     "datagouv",
        "last_update":  ds.get("last_update") or ds.get("created_at") or "",
        "tags":         tags,
        "description":  desc,
        "license":      ds.get("license") or "",
        "resources":    len(ds.get("resources") or []),
    }

def fetch_page(session, q, page, retries=3):
    params = {"q": q, "page": page, "page_size": PAGE_SIZE, "sort": "-last_update"}
    last_err = None
    for attempt in range(1, retries + 1):
        try:
            r = session.get(API_BASE, params=params, timeout=(5, 30))
            r.raise_for_status()
            return r.json()
        except Exception as e:
            last_err = e
            wait = min(2 ** attempt, 10)
            print(f"  ! tentative {attempt}/{retries} : {e} -- retry {wait}s", file=sys.stderr)
            time.sleep(wait)
    raise RuntimeError(f"API injoignable : {last_err}")

def aggregate(q, max_pages, out_path, keep_all):
    session = requests.Session()
    session.headers.update({"User-Agent": "monitor974/2.0 (+local)", "Accept": "application/json"})
    seen = {}
    total_pages = 1
    for page in range(1, max_pages + 1):
        try:
            payload = fetch_page(session, q, page)
        except RuntimeError as e:
            print(f"  X {e}", file=sys.stderr)
            break
        data = payload.get("data") or []
        total_pages = payload.get("page") or total_pages
        total = payload.get("total", "?")
        if not data:
            break
        for ds in data:
            if not keep_all and not looks_like_reunion(ds):
                continue
            n = normalize(ds)
            if n["id"]:
                seen[n["id"]] = n
        print(f"  page {page}/{total_pages} -- cumul {len(seen)} (total API {total})")
        if page >= total_pages:
            break
        time.sleep(0.3)
    result = {
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "query": q,
        "count": len(seen),
        "results": list(seen.values()),
    }
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    return len(seen)

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("--q", default=DEFAULT_Q)
    p.add_argument("--pages", type=int, default=3)
    p.add_argument("--out", type=Path, default=OUT_DEFAULT)
    p.add_argument("--all", action="store_true")
    return p.parse_args()

def main():
    args = parse_args()
    try:
        n = aggregate(args.q, args.pages, args.out, keep_all=args.all)
    except Exception as e:
        print(f"X Erreur : {e}", file=sys.stderr)
        return 1
    print(f"OK {n} datasets ecrits dans {args.out}")
    return 0 if n > 0 else 1

if __name__ == "__main__":
    sys.exit(main())
PYEOF
  chmod +x "${BASE_DIR}/scripts/aggregate.py" 2>/dev/null || true
  ok "aggregate.py"
}

write_seed() {
  log "Écriture de seed_car_jaune.py (fallback)…"
  cat > "${BASE_DIR}/scripts/seed_car_jaune.py" <<'PYEOF'
#!/usr/bin/env python3
"""Seed offline : Car Jaune + entrees Reunion."""
import json
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "data" / "reunion_974_v4.json"

SEED = {
    "generated_at": "2026-10-06T00:00:00+0400",
    "query": "seed",
    "count": 0,
    "results": [
        {
            "id": "horaires-du-reseau-interurbain-car-jaune-region-reunion",
            "titre": "Horaires du reseau interurbain Car Jaune - REGION REUNION CR974",
            "url": "https://www.data.gouv.fr/datasets/horaires-du-reseau-interurbain-car-jaune-region-reunion",
            "organisation": "REGION REUNION CR974",
            "portail": "data.gouv.fr",
            "pays": "FR",
            "type_api": "datagouv",
            "last_update": "2020-08-20T00:00:00+00:00",
            "tags": "car jaune, transport, gtfs, reunion, 974, interurbain",
            "description": "Horaires du reseau interurbain Car Jaune. Lignes E1-E4, O1-O4, S1-S6, S21, S31, S51, T, ZO. Tous les autocars sont accessibles PMR et UFR.",
            "license": "Licence Ouverte / Open Licence",
            "resources": 3
        },
        {
            "id": "civis-reseau-transport-saint-pierre",
            "titre": "Reseau de transport CIVIS - Saint-Pierre (974)",
            "url": "https://www.data.gouv.fr/datasets/",
            "organisation": "CIVIS",
            "portail": "data.gouv.fr",
            "pays": "FR",
            "type_api": "datagouv",
            "last_update": "2024-03-12T00:00:00+00:00",
            "tags": "transport, civis, saint-pierre, reunion, gtfs",
            "description": "Donnees GTFS du reseau CIVIS (sud de La Reunion).",
            "license": "ODbL",
            "resources": 5
        },
        {
            "id": "inondations-risques-reunion-974",
            "titre": "Zones inondables - La Reunion (974)",
            "url": "https://www.data.gouv.fr/datasets/",
            "organisation": "DEAL Reunion",
            "portail": "data.gouv.fr",
            "pays": "FR",
            "type_api": "datagouv",
            "last_update": "2023-11-02T00:00:00+00:00",
            "tags": "risque, inondation, 974, reunion, environnement",
            "description": "Cartographie des zones inondables reglementaires.",
            "license": "Licence Ouverte",
            "resources": 2
        }
    ]
}
SEED["count"] = len(SEED["results"])
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(SEED, ensure_ascii=False, indent=2), encoding="utf-8")
print(f"OK seed ecrit : {OUT} ({SEED['count']} datasets)")
PYEOF
  chmod +x "${BASE_DIR}/scripts/seed_car_jaune.py" 2>/dev/null || true
  ok "seed_car_jaune.py"
}

setup_venv() {
  log "Création du venv Python…"
  if [[ -d "${VENV_DIR}" && -x "${VENV_DIR}/bin/python3" ]]; then
    ok "venv existant réutilisé"
  else
    if ! "${PYTHON_BIN}" -m venv "${VENV_DIR}" 2>>"${LOG_FILE}"; then
      warn "venv indisponible → installation système ignorée"
      return 0
    fi
    ok "venv créé"
  fi
  # shellcheck disable=SC1091
  if ! source "${VENV_DIR}/bin/activate" 2>/dev/null; then
    warn "Activation venv échouée — continuons"
    return 0
  fi
  export VIRTUAL_ENV="${VENV_DIR}"
  log "Mise à jour pip…"
  if ! python3 -m pip install --quiet --upgrade pip --timeout 60 --retries 3 \
        >>"${LOG_FILE}" 2>&1; then
    warn "pip upgrade échoué — on continue"
  fi
  log "Installation des dépendances…"
  if ! python3 -m pip install --quiet --timeout 60 --retries 3 \
        -r "${BASE_DIR}/scripts/requirements.txt" \
        >>"${LOG_FILE}" 2>&1; then
    warn "pip install 'requests' échoué (fallback global possible)"
  else
    ok "Dépendances installées"
  fi
  return 0
}

write_run_sh() {
  log "Écriture de run.sh…"
  cat > "${BASE_DIR}/run.sh" <<'RUNEOF'
#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-8000}"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

echo "-> Agrégation…"
if ! python3 scripts/aggregate.py --pages "${PAGES:-3}"; then
  echo "! API injoignable -> fallback seed"
  python3 scripts/seed_car_jaune.py
fi

echo "-> Serveur : http://localhost:${PORT}"
exec python3 -m http.server "${PORT}" --bind 127.0.0.1
RUNEOF
  chmod +x "${BASE_DIR}/run.sh" 2>/dev/null || true
  ok "run.sh"
}

write_refresh_sh() {
  log "Écriture de refresh.sh (cron)…"
  cat > "${BASE_DIR}/refresh.sh" <<'REFEOF'
#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="${BASE_DIR}/logs/aggregate.log"
mkdir -p "$(dirname "${LOG}")"
[[ -d "${BASE_DIR}/.venv" ]] && source "${BASE_DIR}/.venv/bin/activate" 2>/dev/null || true
{
  echo "---- $(date -Is) ----"
  if ! python3 "${BASE_DIR}/scripts/aggregate.py" --pages "${PAGES:-3}"; then
    echo "! fallback seed"
    python3 "${BASE_DIR}/scripts/seed_car_jaune.py"
  fi
} >> "${LOG}" 2>&1
REFEOF
  chmod +x "${BASE_DIR}/refresh.sh" 2>/dev/null || true
  ok "refresh.sh"
}

write_update_sh() {
  log "Écriture de update.sh (mise à jour manuelle)…"
  cat > "${BASE_DIR}/update.sh" <<'UPDEOF'
#!/usr/bin/env bash
set -uo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${BASE_DIR}"
[[ -d .venv ]] && source .venv/bin/activate 2>/dev/null || true

echo "-> Tentative API data.gouv.fr…"
if python3 scripts/aggregate.py --pages "${PAGES:-3}"; then
  echo "OK Mise à jour API réussie"
  exit 0
fi
echo "! API injoignable -> utilisation du seed local"
python3 scripts/seed_car_jaune.py
UPDEOF
  chmod +x "${BASE_DIR}/update.sh" 2>/dev/null || true
  ok "update.sh"
}

write_index_placeholder() {
  if [[ -f "${BASE_DIR}/index.html" ]]; then
    ok "index.html déjà présent — conservé"
    return 0
  fi
  warn "index.html absent — placeholder créé"
  cat > "${BASE_DIR}/index.html" <<'HTMLEOF'
<!DOCTYPE html>
<html lang="fr"><head><meta charset="UTF-8">
<title>Monitor 974 — placeholder</title></head>
<body style="font-family:sans-serif;padding:2rem">
<h1>Monitor La Reunion 974</h1>
<p>Remplace ce fichier par ton dashboard HTML complet.</p>
<p>Flux attendu : <code>data/reunion_974_v4.json</code></p>
</body></html>
HTMLEOF
  ok "index.html placeholder"
}

write_readme() {
  log "Écriture de README.md…"
  cat > "${BASE_DIR}/README.md" <<'MDEOF'
# Monitor La Reunion 974

Veille continue sur les datasets open data de La Reunion.

## Demarrage

    ./setup.sh
    ./run.sh    # http://localhost:8000

## Mise a jour manuelle

    ./update.sh

## Cron horaire

    0 * * * * /chemin/vers/monitor974/refresh.sh

## Structure

- index.html
- data/reunion_974_v4.json
- scripts/aggregate.py
- scripts/seed_car_jaune.py
- update.sh / refresh.sh / run.sh
- logs/setup.log / logs/aggregate.log

## Variables

| Var | Defaut | Role |
|---|---|---|
| PORT | 8000 | port HTTP |
| PAGES | 3 | pages API max |
| PYTHON_BIN | python3 | interpreteur |
MDEOF
  ok "README.md"
}

prime_data() {
  log "Génération du premier JSON…"
  [[ -d "${VENV_DIR}" ]] && source "${VENV_DIR}/bin/activate" 2>/dev/null || true
  local py="${PYTHON_BIN}"
  [[ -x "${VENV_DIR}/bin/python3" ]] && py="${VENV_DIR}/bin/python3"

  if "${py}" "${BASE_DIR}/scripts/aggregate.py" --pages 2 >>"${LOG_FILE}" 2>&1; then
    ok "JSON généré via API"
    return 0
  fi
  warn "API injoignable → seed local"
  if "${py}" "${BASE_DIR}/scripts/seed_car_jaune.py" >>"${LOG_FILE}" 2>&1; then
    ok "Seed appliqué"
    return 0
  fi
  err "Seed échoué aussi — vérifie ${LOG_FILE}"
  return 1
}

summary() {
  local count="?"
  if [[ -f "${BASE_DIR}/data/reunion_974_v4.json" ]]; then
    count="$("${PYTHON_BIN}" -c \
      'import json,sys;print(json.load(open(sys.argv[1]))["count"])' \
      "${BASE_DIR}/data/reunion_974_v4.json" 2>/dev/null || echo '?')"
  fi
  cat <<EOF

${C_GREEN}==========================================================${C_RESET}
  ${C_GREEN}Installation terminee${C_RESET}   (${count} datasets)

  Projet : ${BASE_DIR}
  JSON   : ${BASE_DIR}/data/reunion_974_v4.json
  Logs   : ${BASE_DIR}/logs/setup.log

  ${C_YELLOW}Demarrage :${C_RESET}
      ./run.sh                    -> http://localhost:${PORT}

  ${C_YELLOW}Mise a jour manuelle :${C_RESET}
      ./update.sh

  ${C_YELLOW}Cron horaire :${C_RESET}
      0 * * * * ${BASE_DIR}/refresh.sh

  ${C_YELLOW}Diagnostic :${C_RESET}
      tail -n 50 logs/setup.log
${C_GREEN}==========================================================${C_RESET}
EOF
}

main() {
  banner
  check_prereqs || true
  create_tree    || true
  write_requirements
  write_aggregator
  write_seed
  setup_venv     || true
  write_run_sh
  write_refresh_sh
  write_update_sh
  write_index_placeholder
  write_readme
  prime_data     || warn "Le JSON devra être régénéré via ./update.sh"
  summary
  exit 0
}

main "$@"