cat > scripts/fetch_car_jaune.py <<'PYEOF'
#!/usr/bin/env python3
"""Télécharge le GTFS Car Jaune À JOUR (2025-2027)."""
import sys
from pathlib import Path
try:
    import requests
except ImportError:
    print("X 'requests' manquant → pip install -r scripts/requirements.txt", file=sys.stderr)
    sys.exit(2)

GTFS_URL = "https://pysae.com/api/v2/groups/car-jaune/gtfs/pub"
OUT_DIR = Path(__file__).resolve().parent.parent / "data" / "car_jaune"

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    dest = OUT_DIR / "car-jaune-gtfs-actuel.zip"
    print(f"→ Téléchargement : {GTFS_URL}")
    try:
        r = requests.get(GTFS_URL, timeout=120, stream=True,
                         headers={"User-Agent": "monitor-car-jaune/1.0"})
        r.raise_for_status()
        with open(dest, "wb") as f:
            for chunk in r.iter_content(8192):
                f.write(chunk)
        size = dest.stat().st_size
        print(f"✓ {size:,} octets → {dest.name}")
    except Exception as e:
        print(f"X Échec : {e}", file=sys.stderr)
        sys.exit(1)

if __name__ == "__main__":
    main()
PYEOF

chmod +x scripts/fetch_car_jaune.py