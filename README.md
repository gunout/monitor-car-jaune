# 🚌 Car Jaune 974 — Monitor Réseau Interurbain

![La Réunion](https://img.shields.io/badge/La%20Réunion-974-0055a4?style=for-the-badge)
![GTFS](https://img.shields.io/badge/GTFS-2025--2027-ffcc00?style=for-the-badge)
![ODbL](https://img.shields.io/badge/license-ODbL-e1000f?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![Pages](https://img.shields.io/badge/GitHub%20Pages-Live-00a95f?style=for-the-badge&logo=github&logoColor=white)

Dashboard web autonome pour explorer le réseau de transport interurbain **Car Jaune** de La Réunion, à partir du GTFS officiel (export HASTUS 2025).

## ✨ Fonctionnalités

- 🚌 **16 lignes** : E1-E4 · O1-O4 · S1-S6 · T · ZO
- ⚡ **Lignes Express** : E1X · O1X · TX
- 📍 **468 arrêts** avec coordonnées GPS
- 🚏 **2 286 trajets** · **36 858 passages**
- 🕐 **Tous les horaires** d'arrivée et de départ par arrêt
- 📍 **Géolocalisation** : détecte votre position
- 🎯 **Prochain car** : temps d'attente en temps réel
- 🗺️ **Itinéraire** : calcul de trajet A → B
- 🗺️ **Carte interactive** (Leaflet + OpenStreetMap)
- 🔔 **Notifications** : soyez prévenu quand le car approche
- 🔍 Recherche par ligne, arrêt ou destination
- 🎨 Filtres : Express · Est · Ouest · Sud · Aéroport
- 📱 Responsive (mobile/tablette/desktop)
- ⚡ Zéro dépendance (HTML + CSS + JS vanilla)

## 🚀 Installation

1. Cloner le repo : `git clone https://github.com/gunout/monitor-car-jaune.git`
2. Entrer dans le dossier : `cd monitor-car-jaune`
3. Créer le venv : `python3 -m venv .venv && source .venv/bin/activate`
4. Installer les dépendances : `pip install -r scripts/requirements.txt`
5. Télécharger le GTFS 2025 : `python scripts/fetch_car_jaune.py`
6. Parser le GTFS : `python scripts/parse_car_jaune_full.py`
7. Indexer les coordonnées GPS : `python scripts/compute_distances.py`
8. Lancer le serveur : `./run.sh`

Ouvrir ensuite **http://localhost:7050** dans le navigateur.

## 🛠️ Commandes utiles

| Commande | Rôle |
|---|---|
| `./run.sh` | Lance le serveur sur le port 7050 |
| `./update.sh` | Re-télécharge le GTFS et re-parse |
| `./refresh.sh` | Version silencieuse (cron) |
| `python3 scripts/fetch_car_jaune.py` | Télécharge le GTFS brut |
| `python3 scripts/parse_car_jaune_full.py` | Convertit GTFS → JSON |
| `python3 scripts/compute_distances.py` | Ajoute les coordonnées GPS |

## 📁 Structure

- `index.html` — Dashboard Car Jaune (avec GPS, carte, itinéraire)
- `run.sh` — Lancement du serveur
- `update.sh` — Mise à jour du GTFS
- `refresh.sh` — Version cron
- `scripts/fetch_car_jaune.py` — Téléchargement du GTFS 2025
- `scripts/parse_car_jaune_full.py` — Conversion GTFS → JSON complet
- `scripts/compute_distances.py` — Index des arrêts avec GPS
- `data/car_jaune_full.json` — Données parsées (2 286 trajets)
- `data/car_jaune/` — GTFS brut (zip)

## 📊 Source des données

- **Dataset** : [Horaires du réseau interurbain Car Jaune](https://www.data.gouv.fr/datasets/horaires-du-reseau-interurbain-car-jaune-region-reunion)
- **Producteur** : REGION REUNION CR974
- **Licence** : ODbL
- **Format** : GTFS (export HASTUS)
- **Dernière MAJ** : 2025

### Contenu du GTFS

| Table | Enregistrements |
|---|---|
| agency.txt | 1 |
| stops.txt | 468 |
| routes.txt | 16 |
| trips.txt | 2 286 |
| stop_times.txt | 36 858 |
| calendar.txt | 6 |

## 🎯 Signification des lignes

| Préfixe | Zone | Description |
|---|---|---|
| **E** | 🔴 Est | Saint-Benoît / Saint-André |
| **O** | 🟠 Ouest | Saint-Paul |
| **S** | 🟢 Sud | Saint-Pierre / Saint-Joseph |
| **T** | 🟣 Aéroport | Desserte Roland Garros |
| **ZO** | ⚫ Zoom | Ancien Z'éclair |
| **X** | ⚡ Express | Direct, moins d'arrêts |

## ⚠️ Notes

Le GTFS officiel contient **16 lignes**. Les lignes scolaires **S21\*** (St-Pierre ↔ Université Tampon), **S31** (St-Joseph ↔ St-Pierre) et **S51** (Entre-Deux ↔ St-Louis) ne sont pas incluses dans l'export HASTUS.

## 📄 Licence

- **Code** : MIT
- **Données** : ODbL — © REGION REUNION CR974

## 🔗 Liens

- 🚌 [Dashboard en ligne](https://gunout.github.io/monitor-car-jaune/)
- 📦 [Repo GitHub](https://github.com/gunout/monitor-car-jaune)
- 🌐 [Car Jaune officiel](https://www.carjaune.re/)

---

⭐ Si ce projet vous est utile, donnez-lui une étoile !
