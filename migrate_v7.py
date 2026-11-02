"""
migrate_v7.py
=============
V7 - Abre Chrome com --remote-debugging-port usando um diretorio temporario
separado, faz login manual via Playwright e coleta dados.

Estrategia: usar Playwright launch_persistent_context com um diretorio NOVO
para evitar conflito com o perfil principal. Faz login na hora.
Intercepta requisicoes no nivel mais baixo possivel.
"""

import asyncio
import json
import re
import sys

OUTPUT_FILE = "copafacil_data.json"
SERVICE_ACCOUNT = "tvi-news-service-account.json"
EMAIL = "lalomoraes@copafacil.com"
SENHA = "L@lO2@25"

collected = {
    "championships": {},
    "teams": {},
    "players": {},
    "matches": {},
    "events": {},
    "raw_firestore": [],
    "all_network": [],
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
    if "copafacil-web" not in name: return
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
        print(f"  [PART] {parts[3][:15]}")
    elif len(parts) >= 6 and parts[4] in ("events","lances","eventos"):
        collected["events"].setdefault(parts[3], []).append(fields)

def process_body(body, url=""):
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
    import os, tempfile, shutil

    print("=== MIGRACAO COPAFACIL V7 ===")
    print("Abrindo novo Chromium com interceptacao completa de rede\n")

    # Diretorio temporario para perfil novo
    tmp_dir = os.path.join(tempfile.gettempdir(), "cf_migration_profile")
    if os.path.exists(tmp_dir):
        shutil.rmtree(tmp_dir, ignore_errors=True)
    os.makedirs(tmp_dir, exist_ok=True)
    print(f"Perfil temporario: {tmp_dir}")

    async with async_playwright() as p:
        # Usa launch_persistent_context com diretorio novo (sem conflito)
        context = await p.chromium.launch_persistent_context(
            user_data_dir=tmp_dir,
            headless=False,
            slow_mo=100,
            viewport={"width": 1400, "height": 900},
            args=[
                "--disable-blink-features=AutomationControlled",
                "--no-sandbox",
            ]
        )

        page = await context.new_page()

        # Intercepta TUDO via route
        async def handle_route(route):
            request = route.request
            url = request.url
            await route.continue_()

        # Intercepta respostas Firestore
        async def on_response(response):
            url = response.url
            if "firestore.googleapis.com" not in url and "firebase" not in url:
                return
            # Salva para debug
            collected["all_network"].append({
                "url": url[:150],
                "status": response.status,
                "content_type": response.headers.get("content-type", ""),
            })
            try:
                if response.status == 200:
                    ct = response.headers.get("content-type", "")
                    body_bytes = await response.body()
                    if not body_bytes: return
                    # Tenta JSON
                    try:
                        body = json.loads(body_bytes)
                        process_body(body, url)
                        print(f"  NET JSON [{response.status}]: {url[:80]}")
                    except:
                        # Tenta como texto
                        try:
                            txt = body_bytes.decode("utf-8", errors="ignore")
                            if "stringValue" in txt or "documents" in txt:
                                # Pode ser multipart JSON stream (Firestore listen)
                                for line in txt.split("\n"):
                                    line = line.strip().lstrip(",").lstrip("[").rstrip("]")
                                    if line and line.startswith("{"):
                                        try:
                                            obj = json.loads(line)
                                            process_body(obj, url)
                                        except: pass
                                print(f"  NET TXT [{response.status}]: {url[:80]} ({len(txt)} chars)")
                        except: pass
            except Exception as e:
                pass

        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # ── Abre copafacil.com ────────────────────────────────────────────────
        print("Abrindo copafacil.com...")
        await page.goto("https://copafacil.com/user", timeout=60000)
        await page.wait_for_timeout(5000)
        await page.screenshot(path="v7_01.png")

        # Verifica estado
        print(f"URL: {page.url}")
        txt = await page.evaluate("() => document.body ? document.body.innerText.substring(0,200) : ''")
        print(f"Texto: {txt}")

        # ── Login ─────────────────────────────────────────────────────────────
        print("\nFazendo login...")

        # Clica em Entrar se necessario
        try:
            btn = page.get_by_text("Entrar", exact=True).first
            if await btn.is_visible(timeout=3000):
                await btn.click()
                await page.wait_for_timeout(2000)
                print("  Clicou Entrar")
        except: pass

        # Tenta todos os campos de email possiveis
        preencheu_email = False
        for sel in ['input[type="email"]', 'input[name="email"]', 'input[name="username"]',
                    'input[placeholder*="mail" i]', 'input[placeholder*="usu" i]',
                    'input[placeholder*="ogin" i]']:
            try:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1500):
                    await el.click()
                    await el.fill(EMAIL)
                    print(f"  Email: {sel}")
                    preencheu_email = True
                    break
            except: pass

        if not preencheu_email:
            # Tenta qualquer input visivel
            try:
                inputs = await page.locator("input:visible").all()
                print(f"  Inputs visiveis: {len(inputs)}")
                if inputs:
                    await inputs[0].click()
                    await inputs[0].fill(EMAIL)
                    print("  Email no primeiro input")
                    preencheu_email = True
            except: pass

        await page.wait_for_timeout(500)

        preencheu_senha = False
        for sel in ['input[type="password"]', 'input[name="password"]',
                    'input[placeholder*="senha" i]', 'input[placeholder*="pass" i]']:
            try:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1500):
                    await el.click()
                    await el.fill(SENHA)
                    print(f"  Senha: {sel}")
                    preencheu_senha = True
                    break
            except: pass

        await page.screenshot(path="v7_02_campos.png")

        # Submit
        enviou = False
        for sel in ['button[type="submit"]', 'button:has-text("Login")',
                    'button:has-text("Entrar")', 'button:has-text("Fazer Login")']:
            try:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1500):
                    await el.click()
                    print(f"  Submit: {sel}")
                    enviou = True
                    break
            except: pass

        if not enviou:
            await page.keyboard.press("Enter")
            print("  Submit via Enter")

        print("Aguardando login (12s)...")
        await page.wait_for_timeout(12000)
        await page.screenshot(path="v7_03_logado.png")

        print(f"URL apos login: {page.url}")
        txt2 = await page.evaluate("() => document.body ? document.body.innerText.substring(0,300) : ''")
        print(f"Texto apos login: {txt2}")
        print(f"Docs capturados: {len(collected['raw_firestore'])}")
        print(f"Net calls: {len(collected['all_network'])}")

        # Mostra todas as chamadas de rede Firebase
        if collected["all_network"]:
            print("Chamadas Firebase interceptadas:")
            for n in collected["all_network"][:10]:
                print(f"  [{n['status']}] {n['url'][:100]}")

        # ── Navega por campeonatos ─────────────────────────────────────────────
        print("\nNavegando pelos campeonatos...")

        camp_names = ["Copa TVitapê 2026", "Varzeano Itapetininga 2026",
                      "Copa TVitapê 2025", "Varzeano Itapetininga 2025",
                      "Copa TV", "Varzeano"]

        for i, nome in enumerate(camp_names[:4]):
            print(f"\n[{i+1}] {nome}")
            await page.goto("https://copafacil.com/user", timeout=20000)
            await page.wait_for_timeout(5000)

            try:
                el = page.get_by_text(nome, exact=False).first
                if await el.is_visible(timeout=5000):
                    await el.click()
                    await page.wait_for_timeout(8000)
                    print(f"  URL: {page.url}")
                    print(f"  Docs: {len(collected['raw_firestore'])}")
                    await page.screenshot(path=f"v7_camp{i}.png")

                    for aba in ["Jogos","Partidas","Times","Equipes","Classificacao","Artilharia"]:
                        try:
                            a = page.get_by_text(aba, exact=False).first
                            if await a.is_visible(timeout=2000):
                                await a.click()
                                await page.wait_for_timeout(4000)
                                print(f"    {aba}: {len(collected['raw_firestore'])} docs")
                        except: pass
                else:
                    print(f"  Nao encontrado")
            except Exception as e:
                print(f"  Erro: {e}")

        # Painel lateral
        for secao in ["Cadastro de equipes","Cadastro de jogadores"]:
            await page.goto("https://copafacil.com/user", timeout=15000)
            await page.wait_for_timeout(4000)
            try:
                el = page.get_by_text(secao, exact=False).first
                if await el.is_visible(timeout=3000):
                    await el.click()
                    await page.wait_for_timeout(5000)
                    print(f"\n{secao}: {len(collected['raw_firestore'])} docs")
                    await page.screenshot(path=f"v7_{secao[:6].replace(' ','_')}.png")
            except: pass

        # ── RESULTADO ─────────────────────────────────────────────────────────
        print("\n\n=== RESULTADO FINAL ===")
        print(f"Championships: {len(collected['championships'])}")
        print(f"Teams: {sum(len(v) for v in collected['teams'].values())}")
        print(f"Players: {sum(len(v) for v in collected['players'].values())}")
        print(f"Matches: {sum(len(v) for v in collected['matches'].values())}")
        print(f"Raw docs: {len(collected['raw_firestore'])}")
        print(f"Net calls Firebase: {len(collected['all_network'])}")

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(collected, f, ensure_ascii=False, indent=2, default=str)
        print(f"Salvo: {OUTPUT_FILE}")

        await page.wait_for_timeout(3000)
        await context.close()

    # Limpa temp
    import shutil
    try: shutil.rmtree(tmp_dir, ignore_errors=True)
    except: pass

    if collected["championships"] or collected["raw_firestore"]:
        import_to_tvi()
    else:
        print("\nNenhum dado capturado.")
        print("Verifique screenshots v7_*.png e o arquivo copafacil_data.json")

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
    print("Importacao concluida!")

if __name__ == "__main__":
    asyncio.run(run())
