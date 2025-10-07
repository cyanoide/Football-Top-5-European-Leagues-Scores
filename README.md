# ⚽ European Football Data Automation

Ce projet automatise la récupération et la mise à jour des résultats des **5 grands championnats européens**  
(Ligue 1, La Liga, Bundesliga, Serie A, Premier League) à partir de données **Understat**.  
Les résultats sont exportés en Excel, puis mis à jour automatiquement dans un **Google Sheets**.

---

## 🧩 Fonctionnement global

1. **R** extrait et assemble les résultats des championnats  
   → création d’un fichier Excel (`output/Ligues Football EU 2025_2026.xlsx`)

2. **Python** lit ce fichier et met automatiquement à jour votre **Google Sheets**

3. Le tout peut être lancé **d’un simple `python push_xlsx_to_gsheets.py`**

---

## 🚀 Installation

### 1️⃣ Cloner le projet
```bash
git clone https://github.com/<votre-nom-utilisateur>/<nom-du-repo>.git
cd <nom-du-repo>
```bash

2️⃣ Installer les dépendances R
Ouvrez R ou RStudio, puis exécutez :

r
Copier le code
install.packages(c("worldfootballR", "dplyr", "readr", "lubridate", "openxlsx"))
3️⃣ Installer les dépendances Python
Assurez-vous d’avoir Python ≥ 3.10 installé, puis dans le terminal :

bash
Copier le code
pip install pandas openpyxl gspread google-auth google-auth-oauthlib google-auth-httplib2
🔐 Configuration Google Cloud API
Rendez-vous sur console.cloud.google.com

Créez un nouveau projet (ou utilisez-en un existant)

Activez l’API suivante :

✅ Google Sheets API

✅ Google Drive API

Allez dans “Identifiants” → “Créer des identifiants” → “Compte de service”

Téléchargez le fichier JSON (ex. service_account.json)

Placez-le à la racine du projet

Partagez votre Google Sheet avec l’adresse e-mail du compte de service
(visible dans le fichier JSON) en tant qu’Éditeur

🗂️ Structure du projet
bash
Copier le code
📁 racine du projet
├── push_xlsx_to_gsheets.py     # Script Python principal
├── R Ligue Foot.r              # Script R qui extrait et exporte les données
├── service_account.json        # Identifiants Google Cloud (à ajouter manuellement)
├── 📁 output/                  # Contiendra l’Excel généré automatiquement
└── README.md
▶️ Utilisation
Une fois tout installé et configuré :

bash
Copier le code
python push_xlsx_to_gsheets.py
👉 Le script :

Exécute le code R automatiquement

Génère le fichier Excel dans output/

Met à jour votre Google Sheet (onglet DATA)

Vous verrez en fin d’exécution un message du type :

bash
Copier le code
✅ Feuille 'DATA' mise à jour (80 lignes, 25 colonnes).
🔗 https://docs.google.com/spreadsheets/d/xxxxxxxxxxxxxx/edit#gid=0
💡 Conseils
Si Rscript n’est pas reconnu, vérifiez son chemin avec which Rscript et ajustez-le dans le code Python.

Le dossier output/ doit exister (sinon créez-le une fois pour toutes).

Vous pouvez planifier une exécution automatique quotidienne avec cron (Mac/Linux) ou le Planificateur de tâches (Windows).

📄 Licence
Ce projet est distribué sous licence MIT.

Auteur : Constantin Moreira
🧠 Projet combinant R, Python et Google Cloud pour un suivi data football automatisé.
