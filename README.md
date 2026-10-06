# 🚌 Car Jaune 974 — Monitor Réseau Interurbain

![La Réunion](https://img.shields.io/badge/La%20Réunion-974-0055a4?style=for-the-badge)
![GTFS](https://img.shields.io/badge/GTFS-HASTUS%202020-ffcc00?style=for-the-badge)
![ODbL](https://img.shields.io/badge/license-ODbL-e1000f?style=for-the-badge)
![Python](https://img.shields.io/badge/Python-3.12-3776AB?style=for-the-badge&logo=python&logoColor=white)
![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![Pages](https://img.shields.io/badge/GitHub%20Pages-Live-00a95f?style=for-the-badge&logo=github&logoColor=white)

Dashboard web autonome pour explorer le réseau de transport interurbain **Car Jaune** de La Réunion, à partir du GTFS officiel (export HASTUS 2020).

## ✨ Fonctionnalités

- 🚌 **16 lignes** : E1-E4 · O1-O4 · S1-S6 · T · ZO
- 📍 **295 arrêts** avec horaires de passage
- 🚏 **1 978 trajets** · **31 586 passages**
- 🔍 Recherche par ligne, arrêt ou destination
- 🎯 Filtres : Express · Ouest · Sud · Aéroport · Zoom
- 🧭 Directions aller/retour
- 📱 Responsive (mobile/tablette/desktop)
- ⚡ Zéro dépendance (HTML + CSS + JS vanilla)

## 🚀 Installation

1. Cloner le repo : `git clone https://github.com/gunout/monitor-car-jaune.git`
2. Entrer dans le dossier : `cd monitor-car-jaune`
3. Lancer l'installation : `./setup.sh`
4. Activer le venv : `source .venv/bin/activate`
5. Télécharger le GTFS : `python scripts/fetch_car_jaune.py`
6. Parser le GTFS : `python scripts/parse_car_jaune.py`
7. Lancer le serveur : `PORT=7050 ./run.sh`

Ouvrir ensuite **http://localhost:7050** dans le navigateur.

## 📁 Structure

- `index.html` — Dashboard Car Jaune
- `setup.sh` — Installation
- `run.sh` — Lancement du serveur
- `scripts/fetch_car_jaune.py` — Téléchargement du GTFS
- `scripts/parse_car_jaune.py` — Conversion GTFS → JSON
- `data/car_jaune.json` — Données parsées
- `data/reunion_974_v4.json` — Datasets open data

## 📊 Source des données

- **Dataset** : [Horaires du réseau interurbain Car Jaune](https://www.data.gouv.fr/datasets/horaires-du-reseau-interurbain-car-jaune-region-reunion)
- **Producteur** : REGION REUNION CR974
- **Licence** : ODbL
- **Format** : GTFS (export HASTUS)
- **Dernière MAJ** : 2020-08-20

## ⚠️ Notes

Le GTFS officiel contient **16 lignes**. Les lignes scolaires **S21*** (St-Pierre ↔ Université Tampon), **S31** (St-Joseph ↔ St-Pierre) et **S51** (Entre-Deux ↔ St-Louis) ne sont pas incluses dans l'export HASTUS 2020.

## 📄 Licence

- **Code** : MIT
- **Données** : ODbL — © REGION REUNION CR974

## 🔗 Liens

- 🚌 [Dashboard en ligne](https://gunout.github.io/monitor-car-jaune/)
- 📦 [Repo GitHub](https://github.com/gunout/monitor-car-jaune)
- 🌐 [Car Jaune officiel](https://www.carjaune.re/)

---

⭐ Si ce projet vous est utile, donnez-lui une étoile !
