#!/usr/bin/env python3
"""Ajoute un index des arrêts avec coordonnées GPS."""
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
JSON_IN = BASE / "data" / "car_jaune_full.json"

def main():
    d = json.load(open(JSON_IN, encoding="utf-8"))
    
    stops_map = {}
    for line in d["lines"]:
        for dep in line["departures"]:
            for s in dep["stops"]:
                name = s["stop"]
                if name not in stops_map:
                    try:
                        lat = float(s.get("lat") or 0)
                        lon = float(s.get("lon") or 0)
                        if lat and lon:
                            stops_map[name] = {
                                "name": name,
                                "lat": lat,
                                "lon": lon,
                                "lines": set(),
                            }
                    except (ValueError, TypeError):
                        continue
                if name in stops_map:
                    stops_map[name]["lines"].add(line["code"])
    
    for s in stops_map.values():
        s["lines"] = sorted(s["lines"])
    
    d["stops_index"] = sorted(stops_map.values(), key=lambda x: x["name"])
    
    Path(JSON_IN).write_text(
        json.dumps(d, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    print(f"OK {len(d['stops_index'])} arrêts indexés avec GPS")

if __name__ == "__main__":
    main()
