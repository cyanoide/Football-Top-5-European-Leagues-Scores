import os
import math
import pathlib
import subprocess
import pandas as pd
import gspread
from google.oauth2.service_account import Credentials
from gspread.exceptions import SpreadsheetNotFound, WorksheetNotFound

# ====== CONFIG À ADAPTER ======
SPREADSHEET_ID = "1esAMmI-il9cJEbntat7OZ-bhweZIS5iawX3wevUsUSc"  # ID OU URL du doc
SHEET_NAME = "DATA"                   # onglet cible
XLSX_PATH = "output/Ligues Football EU 2025_2026.xlsx"  # chemin vers le fichier créé par R
XLSX_SHEET = 0                        # 0 = première feuille, ou "Résultats" si vous avez nommé la feuille
CREDS_PATH = "service_account.json"   # chemin vers vos credentials
CHUNK_ROWS = 10000                    # lignes envoyées par batch
R_SCRIPT_PATH = pathlib.Path("/Users/constantinmoreira/R Ligue Foot.r").resolve()
# ==============================

SCOPE = [
    "https://www.googleapis.com/auth/spreadsheets",
    "https://www.googleapis.com/auth/drive",
]

def run_r_script():
    print("▶️  Lancement du script R...")
    result = subprocess.run(
        ["/Library/Frameworks/R.framework/Resources/bin/Rscript", "--vanilla", str(R_SCRIPT_PATH)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print("❌ Erreur dans le script R :")
        print(result.stderr)
        raise RuntimeError("Erreur dans le script R")
    print("✅ Script R terminé avec succès.")
    print(result.stdout)

def auth_gspread(creds_path=CREDS_PATH):
    if not os.path.exists(creds_path):
        raise FileNotFoundError(f"Credentials introuvables: {creds_path}")
    creds = Credentials.from_service_account_file(creds_path, scopes=SCOPE)
    gc = gspread.authorize(creds)
    # log utile
    try:
        print(f"🔑 Service account: {creds.service_account_email}")
    except AttributeError:
        print("🔑 Service account chargé (email indisponible avec cette version de google-auth).")
    return gc

def open_or_create_worksheet(gc, spreadsheet_id_or_url, sheet_name, rows=100, cols=26):
    spreadsheet_id_or_url = spreadsheet_id_or_url.strip()
    try:
        # tente ID, puis URL
        try:
            sh = gc.open_by_key(spreadsheet_id_or_url)
        except SpreadsheetNotFound:
            sh = gc.open_by_url(spreadsheet_id_or_url)
    except SpreadsheetNotFound:
        raise PermissionError(
            "❌ Accès refusé ou fichier introuvable.\n"
            "• Vérifie l'ID/URL du Google Sheet.\n"
            "• Partage le fichier avec l'email du compte de service en Éditeur.\n"
            "• Si c'est un Drive partagé, ajoute aussi le compte de service au Drive."
        )

    try:
        ws = sh.worksheet(sheet_name)
    except WorksheetNotFound:
        ws = sh.add_worksheet(title=sheet_name, rows=str(rows), cols=str(cols))
    return sh, ws

def clear_and_resize(ws, nrows, ncols):
    ws.clear()
    ws.resize(rows=max(nrows, 1), cols=max(ncols, 1))

def normalize_df(df: pd.DataFrame) -> pd.DataFrame:
    # remplace NaN par "", évite les conversions inattendues
    # garde les objets tels quels (dates -> str lisibles)
    df = df.copy()
    for c in df.columns:
        if pd.api.types.is_datetime64_any_dtype(df[c]):
            df[c] = df[c].dt.strftime("%Y-%m-%d %H:%M:%S").fillna("")
        else:
            df[c] = df[c].astype(object).where(pd.notna(df[c]), "")
    return df

def update_in_chunks(ws, df: pd.DataFrame, chunk_rows=CHUNK_ROWS):
    values = [df.columns.tolist()] + df.values.tolist()
    total_rows = len(values)
    if total_rows == 0:
        return
    ncols = len(values[0])

    start_row = 1
    while start_row <= total_rows:
        end_row = min(start_row + chunk_rows - 1, total_rows)
        rng = gspread.utils.rowcol_to_a1(start_row, 1) + ":" + gspread.utils.rowcol_to_a1(end_row, ncols)
        ws.update(
            values[start_row-1:end_row],
            range_name=rng,
            value_input_option="RAW"
        )
        start_row = end_row + 1

def main():
    run_r_script()
    # 0) vérifie le fichier Excel
    xlsx_path = pathlib.Path(XLSX_PATH)
    if not xlsx_path.exists():
        raise FileNotFoundError(f"❌ Fichier Excel introuvable: {xlsx_path.resolve()}")

    # 1) Auth
    gc = auth_gspread(CREDS_PATH)

    # 2) Lire l'Excel (une seule feuille)
    try:
        df = pd.read_excel(xlsx_path, sheet_name=XLSX_SHEET, engine="openpyxl")
    except ValueError as e:
        raise ValueError(
            f"❌ Impossible de lire la feuille '{XLSX_SHEET}' dans {xlsx_path.name}.\n"
            f"• Utilise un index (0,1,2,...) ou le nom EXACT de la feuille.\n"
            f"Erreur d'origine: {e}"
        )
    print(f"📂 Excel chargé: {xlsx_path.name} — lignes={len(df)}, colonnes={len(df.columns)}")

    # 2b) normalisation des données
    df = normalize_df(df)

    # 3) Ouvrir / créer l’onglet DATA
    sh, ws = open_or_create_worksheet(gc, SPREADSHEET_ID, SHEET_NAME)

    # 4) Nettoyer + redimensionner
    nrows, ncols = df.shape
    clear_and_resize(ws, nrows + 1, ncols)  # +1 pour l’en-tête

    # 5) Écrire en plusieurs blocs si nécessaire
    update_in_chunks(ws, df, chunk_rows=CHUNK_ROWS)

    print(f"✅ Feuille '{SHEET_NAME}' mise à jour ({nrows} lignes, {ncols} colonnes).")
    print(f"🔗 https://docs.google.com/spreadsheets/d/{sh.id}/edit#gid={ws.id}")

if __name__ == "__main__":
    main()
