import os
import requests
import pandas as pd
from datetime import datetime
import time

PYFLOW_PARAMS = {
    "GENESYS_CLIENT_ID": {
        "type": "global",
        "global_key": "GENESYS_CLIENT_ID",
        "label": "Genesys Client ID",
        "required": True
    },
    "GENESYS_CLIENT_SECRET": {
        "type": "global",
        "global_key": "GENESYS_CLIENT_SECRET",
        "label": "Genesys Client Secret",
        "required": True,
        "secret": True
    },
    "GENESYS_REGION": {
        "type": "global",
        "global_key": "GENESYS_REGION",
        "label": "Región Genesys",
        "required": True
    },
    "OUTPUT_FORMAT": {
        "type": "select",
        "label": "Formato de salida",
        "default": "XLSX",
        "required": True,
        "options": ["XLSX", "CSV"]
    },
    "OUTPUT_DIR": {
        "type": "text",
        "label": "Carpeta de salida",
        "default": "",
        "required": False
    }
}

CLIENT_ID = os.getenv("GENESYS_CLIENT_ID", "").strip()
CLIENT_SECRET = os.getenv("GENESYS_CLIENT_SECRET", "").strip()
REGION = os.getenv("GENESYS_REGION", "mypurecloud.com").strip()
OUTPUT_FORMAT = os.getenv("OUTPUT_FORMAT", "XLSX").strip().upper()
OUTPUT_DIR = os.getenv("OUTPUT_DIR", "").strip()

if not CLIENT_ID:
    raise ValueError("GENESYS_CLIENT_ID es obligatorio.")

if not CLIENT_SECRET:
    raise ValueError("GENESYS_CLIENT_SECRET es obligatorio.")

if not OUTPUT_DIR:
    OUTPUT_DIR = os.path.join(os.getcwd(), "exports")

os.makedirs(OUTPUT_DIR, exist_ok=True)

BASE_URL = f"https://api.{REGION}"
TOKEN_URL = f"https://login.{REGION}/oauth/token"

timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
base_filename = f"Detalle de Listas Genesys {timestamp}"

if OUTPUT_FORMAT == "CSV":
    OUTPUT_FILE = os.path.join(OUTPUT_DIR, f"{base_filename}.csv")
else:
    OUTPUT_FILE = os.path.join(OUTPUT_DIR, f"{base_filename}.xlsx")


def get_token():
    response = requests.post(
        TOKEN_URL,
        data={
            "grant_type": "client_credentials",
            "client_id": CLIENT_ID,
            "client_secret": CLIENT_SECRET
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"}
    )
    response.raise_for_status()
    return response.json()["access_token"]


def get_contact_lists(token):
    headers = {"Authorization": f"Bearer {token}"}

    print("Obteniendo cantidad de páginas...", flush=True)
    first_url = f"{BASE_URL}/api/v2/outbound/contactlists?pageSize=100&pageNumber=1"

    first = requests.get(first_url, headers=headers)
    first.raise_for_status()

    page_count = first.json().get("pageCount", 1)
    results = []

    print(f"Total de páginas: {page_count}", flush=True)

    for page in range(1, page_count + 1):
        print(f"Consultando página {page}/{page_count}", flush=True)

        url = f"{BASE_URL}/api/v2/outbound/contactlists?pageSize=100&pageNumber={page}"
        r = requests.get(url, headers=headers)
        r.raise_for_status()

        entities = r.json().get("entities", [])

        for item in entities:
            results.append({
                "id": item.get("id"),
                "name": item.get("name"),
                "division": item.get("division", {}).get("name"),
                "dateCreated": item.get("dateCreated")
            })

    print(f"Total de listas encontradas: {len(results)}", flush=True)
    return results


def get_contacts_count(token, contact_list_id):
    headers = {
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    }

    url = f"{BASE_URL}/api/v2/outbound/contactlists/{contact_list_id}/contacts/search"

    body = {
        "pageSize": 1,
        "pageNumber": 1
    }

    r = requests.post(url, headers=headers, json=body)
    r.raise_for_status()

    return r.json().get("contactsCount", 0)


def generar_salida(df):
    df["Año"] = df["dateCreated"].astype(str).str[:4]
    df["contactsCount"] = pd.to_numeric(df["contactsCount"], errors="coerce").fillna(0)

    if OUTPUT_FORMAT == "CSV":
        df.to_csv(OUTPUT_FILE, index=False, encoding="utf-8-sig")
        return

    resumen = df.pivot_table(
        index="division",
        columns="Año",
        values=["id", "contactsCount"],
        aggfunc={
            "id": "count",
            "contactsCount": "sum"
        },
        fill_value=0
    )

    resumen.columns = [
        f"{year} {'listas' if metric == 'id' else 'registros'}"
        for metric, year in resumen.columns
    ]

    resumen = resumen.reset_index()
    resumen = resumen.rename(columns={"division": "Listas"})

    total_por_division = df.groupby("division", dropna=False).agg(
        **{
            "Total listas": ("id", "count"),
            "Total registros": ("contactsCount", "sum")
        }
    ).reset_index()

    resumen = resumen.merge(
        total_por_division,
        left_on="Listas",
        right_on="division",
        how="left"
    ).drop(columns=["division"])

    total_listas = int(df["id"].count())
    total_registros = int(df["contactsCount"].sum())

    limite_listas = 1000
    limite_registros = 5000000

    uso_listas = total_listas / limite_listas
    uso_registros = total_registros / limite_registros

    limites = pd.DataFrame({
        "Indicador": ["Límite", "Utilizado", "% Utilizado"],
        "Listas": [limite_listas, total_listas, f"{uso_listas:.0%}"],
        "Registros": [limite_registros, total_registros, f"{uso_registros:.0%}"]
    })

    with pd.ExcelWriter(OUTPUT_FILE, engine="openpyxl") as writer:
        df.to_excel(writer, sheet_name="Base", index=False)
        resumen.to_excel(writer, sheet_name="Resumen", index=False, startrow=0)
        limites.to_excel(writer, sheet_name="Resumen", index=False, startrow=len(resumen) + 4)


def main():
    start = time.time()

    print("===================================", flush=True)
    print("INICIANDO PROCESO", flush=True)
    print("===================================", flush=True)
    print(f"REGION: {REGION}", flush=True)
    print(f"OUTPUT_FORMAT: {OUTPUT_FORMAT}", flush=True)
    print(f"OUTPUT_DIR: {OUTPUT_DIR}", flush=True)

    print("Obteniendo token...", flush=True)
    token = get_token()
    print("Token obtenido correctamente", flush=True)

    print("===================================", flush=True)
    print("Consultando listas...", flush=True)

    lists = get_contact_lists(token)

    print("===================================", flush=True)
    print("Consultando cantidad de contactos por lista...", flush=True)

    total = len(lists)

    for index, item in enumerate(lists, start=1):
        print(f"[{index}/{total}] Procesando: {item['name']}", flush=True)

        try:
            item["contactsCount"] = get_contacts_count(token, item["id"])
        except Exception as e:
            print(f"ERROR en lista {item['name']}: {str(e)}", flush=True)
            item["contactsCount"] = None

    print("===================================", flush=True)
    print("Generando archivo de salida...", flush=True)

    df = pd.DataFrame(lists, columns=[
        "id",
        "name",
        "division",
        "dateCreated",
        "contactsCount"
    ])

    generar_salida(df)

    end = time.time()
    total_minutes = round((end - start) / 60, 2)

    print("===================================", flush=True)
    print("PROCESO FINALIZADO", flush=True)
    print("===================================", flush=True)
    print("Archivo generado correctamente:", flush=True)
    print(OUTPUT_FILE, flush=True)
    print(f"Tiempo total: {total_minutes} minutos", flush=True)


if __name__ == "__main__":
    main()