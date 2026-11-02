"""
migrate_v6.py
=============
V6 - Conecta ao Chrome JA ABERTO via CDP (remote debugging port 9222)
O Chrome foi iniciado com --remote-debugging-port=9222 e ja esta logado.
"""

import asyncio
import json
import re

OUTPUT_FILE = "copafacil_data.json"
SERVICE_ACCOUNT = "tvi-news-service-account.json"

collected = {
    "championships": {},
    "teams": {},
    "players": {},
    "matches": {},
    "events": {},
    "raw_firestore": [],
}

def parse_value(v):
    if not isinstance(v, dict): return v
    if "stringValue" in v: return v["stringValue"]
    if "integerValue" in v: return int(v["integerValue"])
    if "doubleValue" in v: return float(v["doubleValue"])
    if "booleanValue" in v: return v["booleanValue"]
    if "nullValue" in v: return None
    if "timestampValue" in v: return v["timestampValue"]
    if "mapValue" in v: return {k: parse_value(vv) for k, vv in v["mapValue"].get("fields", {}).items()}
    if "arrayValue" in v: return [parse_value(x) for x in v["arrayValue"].get("values", [])]
    if "referenceValue" in v: return v["referenceValue"]
    return v

def parse_doc(doc):
    if not doc or "name" not in doc: return
    name = doc["name"]
    fields = {k: parse_value(v) for k, v in doc.get("fields", {}).items()}
    fields["_id"] = name.split("/")[-1]
    fields["_path"] = name
    collected["raw_firestore"].append(fields)
    parts = name.split("/documents/")[-1].split("/") if "/documents/" in name else []
    if not parts: return
    col = parts[0]
    doc_id = parts[1] if len(parts) > 1 else fields["_id"]
    nome = fields.get("name") or fields.get("nome") or fields.get("title") or doc_id
    if col in ("championships", "campeonatos"):
        collected["championships"][doc_id] = fields
        print(f"  [CAMP] {nome}")
    elif len(parts) >= 4 and parts[2] in ("teams","equipes","times"):
        collected["teams"].setdefault(parts[1], {})[parts[3]] = fields
        print(f"  [TIME] {nome}")
    elif len(parts) >= 4 and parts[2] in ("players","jogadores"):
        collected["players"].setdefault(parts[1], []).append(fields)
        print(f"  [JOG]  {nome}")
    elif len(parts) >= 4 and parts[2] in ("matches","partidas","games","jogos"):
        collected["matches"].setdefault(parts[1], {})[parts[3]] = fields
        print(f"  [PART] {parts[3][:20]}")
    elif len(parts) >= 6 and parts[4] in ("events","lances","eventos"):
        collected["events"].setdefault(parts[3], []).append(fields)
        print(f"  [LANC] min={fields.get('minute',0)}")

def process_body(body):
    if isinstance(body, list):
        for item in body:
            if isinstance(item, dict):
                if "document" in item: parse_doc(item["document"])
                elif "name" in item and "fields" in item: parse_doc(item)
    elif isinstance(body, dict):
        if "documents" in body:
            for doc in body["documents"]: parse_doc(doc)
        elif "name" in body and "fields" in body: parse_doc(body)

async def run():
    from playwright.async_api import async_playwright

    print("=== MIGRACAO COPAFACIL V6 - CDP ===")
    print("Conectando ao Chrome ja aberto (porta 9222)...\n")

    async with async_playwright() as p:
        # Conecta ao Chrome existente via CDP
        try:
            browser = await p.chromium.connect_over_cdp("http://localhost:9222")
            print("Conectado ao Chrome via CDP!")
            contexts = browser.contexts
            print(f"Contextos encontrados: {len(contexts)}")

            if contexts:
                context = contexts[0]
            else:
                context = await browser.new_context()

            pages = context.pages
            print(f"Paginas abertas: {len(pages)}")

            # Pega a pagina da CopáFácil ou abre uma nova
            page = None
            for pg in pages:
                if "copafacil" in pg.url:
                    page = pg
                    print(f"Usando pagina existente: {pg.url}")
                    break

            if not page:
                page = await context.new_page()
                print("Abriu nova pagina")
                await page.goto("https://copafacil.com/user", timeout=60000)
                await page.wait_for_timeout(5000)

        except Exception as e:
            print(f"Erro ao conectar via CDP: {e}")
            print("Tentando abrir novo browser Chromium...")
            browser2 = await p.chromium.launch(headless=False, slow_mo=100)
            context = await browser2.new_context(viewport={"width": 1400, "height": 900})
            page = await context.new_page()
            await page.goto("https://copafacil.com/user", timeout=60000)
            await page.wait_for_timeout(6000)

        # Intercepta respostas Firestore
        async def on_response(response):
            if "firestore.googleapis.com" not in response.url: return
            try:
                if response.status == 200:
                    body = await response.json()
                    if body: process_body(body)
            except: pass

        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # Recarrega para capturar dados iniciais
        print(f"\nURL atual: {page.url}")
        print("Recarregando pagina para capturar dados...")
        await page.reload(timeout=30000)
        await page.wait_for_timeout(6000)
        await page.screenshot(path="v6_01_recarregado.png")

        print(f"Docs apos reload: {len(collected['raw_firestore'])}")
        print(f"Championships: {len(collected['championships'])}")

        # Texto da pagina para diagnostico
        try:
            txt = await page.inner_text("body")
            print(f"Texto da pagina: {txt[:300]}")
        except: pass

        # ── Navega por cada campeonato ─────────────────────────────────────────
        print("\nClicando nos campeonatos...")

        camp_names = ["Copa TVitapê 2026", "Varzeano Itapetininga 2026",
                      "Copa TVitapê 2025", "Varzeano Itapetininga 2025"]

        for i, nome in enumerate(camp_names):
            print(f"\n[{i+1}/4] {nome}")

            # Volta para lista
            await page.goto("https://copafacil.com/user", timeout=30000)
            await page.wait_for_timeout(5000)

            # Clica no campeonato
            try:
                el = page.get_by_text(nome, exact=False).first
                if await el.is_visible(timeout=5000):
                    await el.click()
                    await page.wait_for_timeout(6000)
                    print(f"  URL: {page.url}")
                    print(f"  Docs: {len(collected['raw_firestore'])}")
                    await page.screenshot(path=f"v6_camp{i}.png")

                    # Navega pelas abas
                    for aba in ["Jogos", "Partidas", "Times", "Equipes",
                                "Classificacao", "Artilharia", "Grupos", "Fases"]:
                        try:
                            a = page.get_by_text(aba, exact=False).first
                            if await a.is_visible(timeout=2000):
                                await a.click()
                                await page.wait_for_timeout(4000)
                                print(f"    Aba {aba}: {len(collected['raw_firestore'])} docs")
                        except: pass
                else:
                    print(f"  Elemento '{nome}' nao encontrado")
            except Exception as e:
                print(f"  Erro: {e}")

        # ── Acessa secoes do painel ────────────────────────────────────────────
        print("\nAcessando painel do organizador...")

        for secao in ["Cadastro de equipes", "Cadastro de jogadores", "Arbitragem"]:
            print(f"\nSecao: {secao}")
            await page.goto("https://copafacil.com/user", timeout=20000)
            await page.wait_for_timeout(4000)
            try:
                el = page.get_by_text(secao, exact=False).first
                if await el.is_visible(timeout=3000):
                    await el.click()
                    await page.wait_for_timeout(6000)
                    print(f"  Docs: {len(collected['raw_firestore'])}")
                    await page.screenshot(path=f"v6_{secao[:8].replace(' ','_')}.png")
            except Exception as e:
                print(f"  Erro: {e}")

        # ── RESULTADO ─────────────────────────────────────────────────────────
        print("\n\n=== RESULTADO FINAL ===")
        print(f"Championships: {len(collected['championships'])}")
        print(f"Teams: {sum(len(v) for v in collected['teams'].values())}")
        print(f"Players: {sum(len(v) for v in collected['players'].values())}")
        print(f"Matches: {sum(len(v) for v in collected['matches'].values())}")
        print(f"Events/Lances: {sum(len(v) for v in collected['events'].values())}")
        print(f"Raw docs Firestore: {len(collected['raw_firestore'])}")

        if collected["raw_firestore"]:
            print("\nAmostras de docs capturados:")
            for doc in collected["raw_firestore"][:10]:
                print(f"  {doc.get('_path','?')}")

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(collected, f, ensure_ascii=False, indent=2, default=str)
        print(f"\nSalvo em: {OUTPUT_FILE}")

        await page.wait_for_timeout(3000)

    if collected["championships"] or collected["raw_firestore"]:
        print("\nImportando para TVI Firestore...")
        import_to_tvi()
    else:
        print("\nNenhum dado capturado. Verifique screenshots v6_*.png")
        print("\nDIAGNOSTICO: A CopafFácil pode usar gRPC-web stream (nao JSON REST).")
        print("Solucao alternativa: cadastre os campeonatos manualmente no app TVI.")

def import_to_tvi():
    import firebase_admin
    from firebase_admin import credentials, firestore as fstore
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        db = fstore.client()
    except Exception as e:
        print(f"Erro Firebase: {e}")
        return

    for champ_id, champ in collected["championships"].items():
        nome = champ.get("name") or champ.get("nome") or champ_id
        slug = re.sub(r"[^a-z0-9]", "_", nome.lower()[:30]) + f"_{champ_id[:6]}"
        db.collection("campeonatos").document(slug).set({
            "nome": nome, "esporte": "futebol", "status": "encerrado",
            "organizadorId": "lalomoraes_migrado", "organizadorNome": "Lalo Moraes",
            "logoUrl": champ.get("logo") or champ.get("logoUrl"),
            "migradoDeCopafacil": True, "copafacilId": champ_id,
        })
        print(f"  Campeonato: {nome}")
        for team_id, team in collected["teams"].get(champ_id, {}).items():
            db.collection("campeonatos").document(slug).collection("times").document(team_id).set({
                "campeonatoId": slug,
                "nome": team.get("name") or team.get("nome") or team_id,
                "organizadorId": "lalomoraes_migrado",
            })
        for match_id, match in collected["matches"].get(champ_id, {}).items():
            db.collection("campeonatos").document(slug).collection("partidas").document(match_id).set({
                "campeonatoId": slug,
                "timeANome": match.get("homeTeam") or match.get("teamA") or "Time A",
                "timeBNome": match.get("awayTeam") or match.get("teamB") or "Time B",
                "placarA": int(match.get("homeScore") or match.get("scoreA") or 0),
                "placarB": int(match.get("awayScore") or match.get("scoreB") or 0),
                "status": "encerrada", "copafacilId": match_id,
            })
    print("Importacao concluida! Abra o app TVI.")

if __name__ == "__main__":
    asyncio.run(run())
