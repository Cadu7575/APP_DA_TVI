"""
migrate_v5.py
=============
V5 - Conecta ao perfil do Chrome do usuario (ja logado na CopáFácil)
Usa launch_persistent_context com o perfil real do Chrome.
Assim herda todos os cookies/sessao ja existentes.
"""

import asyncio
import json
import re
import os

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

    print("=== MIGRACAO COPAFACIL V5 - PERFIL EXISTENTE ===\n")

    # Perfil do Chrome do usuario
    chrome_profile = r"C:\Users\Carlos\AppData\Local\Google\Chrome\User Data"

    # Executavel do Chrome
    chrome_exe_paths = [
        r"C:\Program Files\Google\Chrome\Application\chrome.exe",
        r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe",
        r"C:\Users\Carlos\AppData\Local\Google\Chrome\Application\chrome.exe",
    ]
    chrome_exe = None
    for p in chrome_exe_paths:
        if os.path.exists(p):
            chrome_exe = p
            break

    if not chrome_exe:
        print("Chrome nao encontrado! Tentando Edge...")
        edge_paths = [
            r"C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
            r"C:\Program Files\Microsoft\Edge\Application\msedge.exe",
        ]
        for p in edge_paths:
            if os.path.exists(p):
                chrome_exe = p
                chrome_profile = r"C:\Users\Carlos\AppData\Local\Microsoft\Edge\User Data"
                print(f"Usando Edge: {p}")
                break

    print(f"Executavel: {chrome_exe}")
    print(f"Perfil: {chrome_profile}")

    async with async_playwright() as p:
        # Abre Chrome com o perfil existente do usuario (ja logado)
        print("\nAbrindo Chrome com perfil existente (ja logado)...")
        print("AGUARDE - o Chrome vai abrir em alguns segundos...\n")

        try:
            context = await p.chromium.launch_persistent_context(
                user_data_dir=chrome_profile,
                executable_path=chrome_exe,
                headless=False,
                slow_mo=200,
                viewport={"width": 1400, "height": 900},
                args=["--no-first-run", "--no-default-browser-check"],
            )
        except Exception as e:
            print(f"Erro ao abrir com perfil existente: {e}")
            print("Tentando sem perfil (novo login necessario)...")
            browser = await p.chromium.launch(headless=False, slow_mo=200)
            context = await browser.new_context(viewport={"width": 1400, "height": 900})

        page = await context.new_page()

        # Intercepta respostas Firestore
        async def on_response(response):
            if "firestore.googleapis.com" not in response.url: return
            try:
                if response.status == 200:
                    body = await response.json()
                    if body:
                        process_body(body)
            except: pass

        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # ── Navega para a CopáFácil (ja logado pelo cookie) ──────────────────
        print("Navegando para copafacil.com/user...")
        await page.goto("https://copafacil.com/user", timeout=60000)
        await page.wait_for_timeout(6000)
        await page.screenshot(path="v5_01_inicial.png")

        # Verifica estado
        texto = await page.evaluate("() => document.body ? document.body.innerText.substring(0, 300) : 'sem body'")
        print(f"Pagina atual: {texto[:200]}")
        print(f"URL: {page.url}")

        # Aguarda dados carregarem
        await page.wait_for_timeout(4000)
        print(f"Docs apos abertura: {len(collected['raw_firestore'])}")

        # ── Navega pelas secoes do painel ─────────────────────────────────────
        secoes = [
            ("Meus campeonatos", "v5_meus_camp.png"),
            ("Cadastro de equipes", "v5_equipes.png"),
            ("Cadastro de jogadores", "v5_jogadores.png"),
        ]

        for nome_secao, screenshot in secoes:
            print(f"\nAcessando '{nome_secao}'...")
            await page.goto("https://copafacil.com/user", timeout=20000)
            await page.wait_for_timeout(4000)
            try:
                el = page.locator(f"text={nome_secao}").first
                if await el.is_visible(timeout=3000):
                    await el.click()
                    await page.wait_for_timeout(6000)
                    await page.screenshot(path=screenshot)
                    print(f"  OK - docs: {len(collected['raw_firestore'])}")
                else:
                    print(f"  Elemento nao visivel")
            except Exception as e:
                print(f"  Erro: {e}")

        # ── Clica em cada campeonato ───────────────────────────────────────────
        print("\nNavegando pelos campeonatos...")
        await page.goto("https://copafacil.com/user", timeout=20000)
        await page.wait_for_timeout(5000)
        await page.screenshot(path="v5_lista_campeonatos.png")

        # Pega todos os links de campeonatos da pagina
        links = await page.evaluate("""
            () => Array.from(document.querySelectorAll('a[href]'))
                  .map(a => ({ href: a.href, text: a.innerText.trim() }))
                  .filter(l => l.href && l.href.length > 0)
        """)
        print(f"Links encontrados: {len(links)}")
        camp_links = [l for l in links if any(k in l['href'].lower() for k in ['/c/', '/camp', '/championship'])]
        print(f"Links de campeonatos: {len(camp_links)}")
        for l in camp_links[:10]:
            print(f"  {l['href']} | {l['text'][:50]}")

        # Navega por cada link de campeonato
        for i, link in enumerate(camp_links[:8]):
            url = link['href']
            nome = link['text'] or f"camp_{i}"
            print(f"\n[{i+1}] {nome}: {url}")
            await page.goto(url, timeout=30000)
            await page.wait_for_timeout(5000)
            await page.screenshot(path=f"v5_camp_{i}.png")
            print(f"  Docs: {len(collected['raw_firestore'])}")

            # Navega pelas abas
            for aba in ["Partidas", "Times", "Equipes", "Classificacao",
                        "Artilharia", "Grupos", "Jogadores"]:
                try:
                    el = page.locator(f"text={aba}").first
                    if await el.is_visible(timeout=2000):
                        await el.click()
                        await page.wait_for_timeout(3000)
                        print(f"  Aba '{aba}': {len(collected['raw_firestore'])} docs total")
                except: pass

        # Se nao achou links, tenta pelo texto do campeonato na pagina
        if not camp_links:
            print("\nSem links de campeonatos, tentando pelo texto...")
            nomes = ["Copa TVitapê", "Varzeano Itapetininga", "Copa TV", "Varzeano"]
            for nome in nomes:
                try:
                    await page.goto("https://copafacil.com/user", timeout=20000)
                    await page.wait_for_timeout(4000)
                    el = page.locator(f"text={nome}").first
                    if await el.is_visible(timeout=3000):
                        await el.click()
                        await page.wait_for_timeout(6000)
                        print(f"  '{nome}' -> URL: {page.url} | docs: {len(collected['raw_firestore'])}")
                        await page.screenshot(path=f"v5_{nome[:8].replace(' ','_')}.png")
                except Exception as e:
                    print(f"  '{nome}': {e}")

        # ── RESULTADO FINAL ───────────────────────────────────────────────────
        print("\n\n=== RESULTADO FINAL ===")
        print(f"Championships: {len(collected['championships'])}")
        print(f"Teams: {sum(len(v) for v in collected['teams'].values())}")
        print(f"Players: {sum(len(v) for v in collected['players'].values())}")
        print(f"Matches: {sum(len(v) for v in collected['matches'].values())}")
        print(f"Raw docs Firestore: {len(collected['raw_firestore'])}")

        if collected["raw_firestore"]:
            print("\nDocs capturados (primeiros 10):")
            for doc in collected["raw_firestore"][:10]:
                print(f"  {doc.get('_path','?')} | {list(doc.keys())[:4]}")

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(collected, f, ensure_ascii=False, indent=2, default=str)
        print(f"\nSalvo em {OUTPUT_FILE}")

        await page.wait_for_timeout(5000)
        await context.close()

    if collected["championships"] or collected["raw_firestore"]:
        print("\nImportando para TVI News Firestore...")
        import_to_tvi()
    else:
        print("\nNenhum dado capturado.")
        print("Verifique as screenshots v5_*.png")

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
        print(f"  Campeonato criado: {nome}")
        for team_id, team in collected["teams"].get(champ_id, {}).items():
            nome_time = team.get("name") or team.get("nome") or team_id
            db.collection("campeonatos").document(slug).collection("times").document(team_id).set({
                "campeonatoId": slug, "nome": nome_time,
                "organizadorId": "lalomoraes_migrado",
                "logoUrl": team.get("logo") or team.get("shield"),
            })
        for match_id, match in collected["matches"].get(champ_id, {}).items():
            db.collection("campeonatos").document(slug).collection("partidas").document(match_id).set({
                "campeonatoId": slug,
                "timeANome": match.get("homeTeam") or match.get("teamA") or "Time A",
                "timeBNome": match.get("awayTeam") or match.get("teamB") or "Time B",
                "placarA": match.get("homeScore") or match.get("scoreA") or 0,
                "placarB": match.get("awayScore") or match.get("scoreB") or 0,
                "status": "encerrada", "copafacilId": match_id,
            })
    print("Importacao concluida! Abra o app TVI.")

if __name__ == "__main__":
    asyncio.run(run())
