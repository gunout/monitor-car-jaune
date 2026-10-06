#!/usr/bin/env python3
"""Parse le GTFS Car Jaune COMPLET → data/car_jaune_full.json

Extrait TOUS les arrêts et TOUS les horaires pour CHAQUE trajet.
"""
from __future__ import annotations
import csv, io, json, re, sys, zipfile, time
from collections import defaultdict
from pathlib import Path

BASE = Path(__file__).resolve().parent.parent
SRC_DIR = BASE / "data" / "car_jaune"
OUT = BASE / "data" / "car_jaune_full.json"

def find_zip():
    zips = list(SRC_DIR.glob("*.zip"))
    if not zips:
        print("X Aucun .zip trouvé", file=sys.stderr); sys.exit(1)
    zips.sort(key=lambda z: z.stat().st_mtime, reverse=True)
    return zips[0]

def read_csv(zf, name):
    if name not in zf.namelist():
        for n in zf.namelist():
            if n.endswith("/" + name): name = n; break
        else: return []
    with zf.open(name) as f:
        raw = f.read().decode("utf-8-sig", errors="replace")
    return list(csv.DictReader(io.StringIO(raw)))

def clean_time(t):
    """Normalise HH:MM:SS → HH:MM"""
    if not t: return ""
    parts = str(t).split(":")
    if len(parts) < 2: return str(t)
    return parts[0].zfill(2) + ":" + parts[1].zfill(2)

def main():
    zpath = find_zip()
    print(f"→ Lecture : {zpath.name}")
    with zipfile.ZipFile(zpath) as zf:
        agency     = read_csv(zf, "agency.txt")
        stops      = read_csv(zf, "stops.txt")
        routes     = read_csv(zf, "routes.txt")
        trips      = read_csv(zf, "trips.txt")
        stop_times = read_csv(zf, "stop_times.txt")
        calendar   = read_csv(zf, "calendar.txt")
        cal_dates  = read_csv(zf, "calendar_dates.txt")

    print(f"  agency:{len(agency)} stops:{len(stops)} routes:{len(routes)}")
    print(f"  trips:{len(trips)} stop_times:{len(stop_times)}")

    stops_by_id = {s["stop_id"]: s for s in stops}

    # Services
    services = {}
    for c in calendar:
        sid = c["service_id"]
        days = []
        if c.get("monday") == "1": days.append("Lun")
        if c.get("tuesday") == "1": days.append("Mar")
        if c.get("wednesday") == "1": days.append("Mer")
        if c.get("thursday") == "1": days.append("Jeu")
        if c.get("friday") == "1": days.append("Ven")
        if c.get("saturday") == "1": days.append("Sam")
        if c.get("sunday") == "1": days.append("Dim")
        services[sid] = {
            "id": sid,
            "days": days,
            "start": c.get("start_date", ""),
            "end": c.get("end_date", ""),
        }

    # Grouper les stop_times par trip_id
    st_by_trip = defaultdict(list)
    for st in stop_times:
        st_by_trip[st["trip_id"]].append(st)

    # Grouper les trips par route_id
    trips_by_route = defaultdict(list)
    for t in trips:
        trips_by_route[t["route_id"]].append(t)

    # Grouper les routes par code logique
    groups = defaultdict(list)
    for r in routes:
        code = (r.get("route_short_name") or "").strip().upper()
        if not code: code = r.get("route_id", "?")
        groups[code].append(r)

    print(f"\n  {len(routes)} routes → {len(groups)} codes logiques\n")

    # Construire le JSON
    lines = []
    for code in sorted(groups.keys()):
        grp = groups[code]
        name = max((r.get("route_long_name") or "" for r in grp), key=len)
        color = next((r.get("route_color") for r in grp if r.get("route_color")), "")

        route_ids = {r["route_id"] for r in grp}
        all_trips = []
        for rid in route_ids:
            all_trips.extend(trips_by_route.get(rid, []))

        # ─── TOUS les trajets avec TOUS les arrêts ───
        departures = []
        for t in all_trips:
            tid = t["trip_id"]
            sts = sorted(
                st_by_trip.get(tid, []),
                key=lambda x: int(x.get("stop_sequence") or 0)
            )
            if not sts: continue

            # Filtrer les arrêts de test
            real_sts = [s for s in sts
                       if not any(kw in (stops_by_id.get(s["stop_id"], {})
                                        .get("stop_name","")).lower()
                                  for kw in ["test", "xxx", "demo"])]
            if not real_sts: continue

            # ─── TOUS les arrêts avec horaires complets ───
            stops_list = []
            for s in real_sts:
                sid = s["stop_id"]
                stop = stops_by_id.get(sid, {})
                stops_list.append({
                    "stop": stop.get("stop_name", sid),
                    "arr": clean_time(s.get("arrival_time", "")),
                    "dep": clean_time(s.get("departure_time", "")),
                    "lat": stop.get("stop_lat", ""),
                    "lon": stop.get("stop_lon", ""),
                })

            departures.append({
                "trip_id": tid,
                "service_id": t.get("service_id", ""),
                "headsign": (t.get("trip_headsign") or "").strip(),
                "direction": t.get("direction_id", ""),
                "first_departure": stops_list[0]["dep"] if stops_list else "",
                "last_arrival": stops_list[-1]["arr"] if stops_list else "",
                "stops": stops_list,
            })

        # Trier par heure de départ
        # ─── DÉDUPLICATION : même heure + mêmes arrêts + même sens ───
        seen = set()
        unique_departures = []
        for d in departures:
            stops_sig = "|".join(s["stop"] for s in d["stops"][:3])
            key = (
                d["first_departure"],
                d["last_arrival"],
                d["headsign"],
                d["service_id"],
                stops_sig,
                len(d["stops"]),
            )
            if key not in seen:
                seen.add(key)
                unique_departures.append(d)
        departures = unique_departures

        departures.sort(key=lambda d: d["first_departure"])

        directions = sorted({d["headsign"] for d in departures if d["headsign"]})

        lines.append({
            "code": code,
            "name": name,
            "color": color,
            "directions": directions,
            "trips_count": len(departures),
            "stops_count": len(departures[0]["stops"]) if departures else 0,
            "departures": departures,
        })

    result = {
        "source": "GTFS Car Jaune (HASTUS) — COMPLET",
        "zip": zpath.name,
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "counts": {
            "lines": len(lines),
            "stops": len(stops),
            "trips": len(trips),
            "stop_times": len(stop_times),
            "services": len(services),
        },
        "services": services,
        "agency": agency,
        "lines": lines,
    }

    OUT.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"OK {len(lines)} lignes · {sum(l['trips_count'] for l in lines)} trajets")
    print(f"OK écrit dans {OUT}")
    print()
    for l in lines:
        # Calculer le nombre max d'arrêts
        max_stops = max((len(d["stops"]) for d in l["departures"]), default=0)
        min_stops = min((len(d["stops"]) for d in l["departures"]), default=0)
        print(f"  {l['code']:6s} {l['trips_count']:4d} départs · {min_stops}-{max_stops} arrêts · {len(l['directions'])} sens")

if __name__ == "__main__":
    main()