"""
migrate_v4.py
=============
V4 - A pagina e HTML puro (nao Flutter canvas)!
Usa cliques reais nos elementos DOM, faz login correto
e injeta JS para acessar o Firebase SDK ja carregado na pagina.
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
    if not doc or "name" not in doc: return None
    name = doc["name"]
    fields = {k: parse_value(v) for k, v in doc.get("fields", {}).items()}
    fields["_id"] = name.split("/")[-1]
    fields["_path"] = name
    collected["raw_firestore"].append(fields)
    parts = name.split("/documents/")[-1].split("/") if "/documents/" in name else []
    if not parts: return fields
    col = parts[0]
    doc_id = parts[1] if len(parts) > 1 else fields["_id"]
    if col in ("championships", "campeonatos"):
        collected["championships"][doc_id] = fields
        print(f"  [CAMP] {fields.get('name') or fields.get('nome') or doc_id}")
    elif len(parts) >= 4 and parts[2] in ("teams","equipes","times"):
        collected["teams"].setdefault(parts[1], {})[parts[3]] = fields
        print(f"  [TIME] {fields.get('name') or fields.get('nome') or parts[3]}")
    elif len(parts) >= 4 and parts[2] in ("players","jogadores"):
        collected["players"].setdefault(parts[1], []).append(fields)
    elif len(parts) >= 4 and parts[2] in ("matches","partidas","games"):
        collected["matches"].setdefault(parts[1], {})[parts[3]] = fields
    return fields

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

    print("=== MIGRACAO COPAFACIL V4 ===\n")
    print("Esta versao usa elementos HTML reais + injecao de JS Firebase\n")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False, slow_mo=100)
        context = await browser.new_context(viewport={"width": 1400, "height": 900})
        page = await context.new_page()

        # Intercepta respostas Firestore REST
        async def on_response(response):
            if "firestore.googleapis.com" not in response.url: return
            try:
                if response.status == 200:
                    body = await response.json()
                    process_body(body)
            except: pass
        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # ── Abre pagina ───────────────────────────────────────────────────────
        print("Abrindo copafacil.com...")
        await page.goto("https://copafacil.com/user", timeout=60000)
        await page.wait_for_timeout(5000)
        await page.screenshot(path="v4_01_inicial.png")

        # ── Login via elementos HTML ──────────────────────────────────────────
        print("Fazendo login via elementos HTML...")

        # Clica no botao "Entrar" no header se estiver visivel
        try:
            btn_entrar = page.locator("text=Entrar").first
            if await btn_entrar.is_visible(timeout=3000):
                await btn_entrar.click()
                await page.wait_for_timeout(2000)
                print("  Clicou em Entrar")
        except: pass

        # Preenche campo email/usuario
        try:
            # Tenta varios seletores para o campo de email
            for sel in ['input[type="email"]', 'input[placeholder*="mail"]',
                        'input[placeholder*="suario"]', 'input[name="email"]',
                        'input[name="username"]', 'input[placeholder*="Login"]',
                        'input[placeholder*="ogin"]']:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1000):
                    await el.clear()
                    await el.fill(EMAIL)
                    print(f"  Email preenchido via {sel}")
                    break
        except: pass

        # Preenche campo senha
        try:
            for sel in ['input[type="password"]', 'input[placeholder*="enha"]',
                        'input[name="password"]', 'input[placeholder*="assword"]']:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1000):
                    await el.clear()
                    await el.fill(SENHA)
                    print(f"  Senha preenchida via {sel}")
                    break
        except: pass

        await page.screenshot(path="v4_02_campos.png")

        # Submete o form
        try:
            # Tenta botao de submit
            for sel in ['button[type="submit"]', 'button:text("Login")',
                        'button:text("Entrar")', 'button:text("Fazer Login")']:
                el = page.locator(sel).first
                if await el.is_visible(timeout=1000):
                    await el.click()
                    print(f"  Submit via {sel}")
                    break
        except:
            await page.keyboard.press("Enter")
            print("  Submit via Enter")

        print("Aguardando login (10s)...")
        await page.wait_for_timeout(10000)
        await page.screenshot(path="v4_03_apos_login.png")

        # ── Verifica se logou ────────────────────────────────────────────────
        url_atual = page.url
        print(f"URL apos login: {url_atual}")
        print(f"Raw docs apos login: {len(collected['raw_firestore'])}")

        # ── Usa JavaScript para acessar Firebase SDK carregado na pagina ──────
        print("\nTentando acessar Firebase SDK via JavaScript...")
        
        # Verifica o que esta disponivel no escopo global
        globals_js = await page.evaluate("""
            () => {
                const keys = Object.keys(window).filter(k =>
                    k.toLowerCase().includes('firebase') ||
                    k.toLowerCase().includes('firestore') ||
                    k.toLowerCase().includes('auth')
                );
                return {
                    keys: keys,
                    hasFirebase: typeof window.firebase !== 'undefined',
                    hasFirebaseApp: typeof window.firebaseApp !== 'undefined',
                    scripts: Array.from(document.scripts).map(s => s.src).filter(Boolean).slice(0, 10)
                };
            }
        """)
        print(f"Globais Firebase: {globals_js}")

        # Tenta obter o token do usuario logado via Firebase Auth
        token_result = await page.evaluate("""
            async () => {
                try {
                    // Tenta via firebase global
                    if (window.firebase && window.firebase.auth) {
                        const user = window.firebase.auth().currentUser;
                        if (user) {
                            const token = await user.getIdToken();
                            return { uid: user.uid, email: user.email, token: token };
                        }
                    }
                    // Tenta via firebase apps
                    if (window._firebase_app) {
                        return { msg: 'found _firebase_app' };
                    }
                    // Lista todas variaveis
                    return { msg: 'firebase not found in global scope' };
                } catch(e) {
                    return { error: e.message };
                }
            }
        """)
        print(f"Token result: {token_result}")

        # ── Navega pelo painel e campeonatos ──────────────────────────────────
        print("\nNavigando pelo painel...")
        await page.wait_for_timeout(3000)

        # Verifica se existe "Meus campeonatos" no DOM
        try:
            text_content = await page.evaluate("() => document.body.innerText")
            print(f"Texto da pagina (primeiros 500 chars): {text_content[:500]}")
        except: pass

        # Tenta clicar em "Meus campeonatos"
        try:
            el = page.locator("text=Meus campeonatos")
            if await el.count() > 0:
                await el.first.click()
                await page.wait_for_timeout(5000)
                print("Clicou em Meus campeonatos")
                await page.screenshot(path="v4_04_meus_camp.png")
                print(f"Raw docs: {len(collected['raw_firestore'])}")
        except Exception as e:
            print(f"Erro meus campeonatos: {e}")

        # Clica em cada campeonato da lista
        camp_names = ["Copa TVitapê 2026", "Varzeano Itapetininga 2026",
                      "Copa TVitapê 2025", "Varzeano Itapetininga 2025",
                      "Copa TV", "Varzeano"]
        
        for nome in camp_names:
            try:
                # Volta ao painel
                await page.goto("https://copafacil.com/user", timeout=20000)
                await page.wait_for_timeout(4000)

                el = page.locator(f"text={nome}").first
                if await el.is_visible(timeout=3000):
                    await el.click()
                    await page.wait_for_timeout(6000)
                    url = page.url
                    print(f"'{nome}' -> URL: {url}")
                    await page.screenshot(path=f"v4_camp_{nome[:10].replace(' ','_')}.png")

                    # Navega pelas abas
                    for aba in ["Partidas", "Times", "Classificacao", "Artilharia"]:
                        try:
                            a = page.locator(f"text={aba}").first
                            if await a.is_visible(timeout=2000):
                                await a.click()
                                await page.wait_for_timeout(4000)
                                print(f"  Aba {aba}: {len(collected['raw_firestore'])} docs total")
                        except: pass
            except Exception as e:
                print(f"'{nome}': {e}")

        # ── Tenta "Cadastro de equipes" ───────────────────────────────────────
        print("\nAcessando Cadastro de equipes...")
        await page.goto("https://copafacil.com/user", timeout=20000)
        await page.wait_for_timeout(4000)
        try:
            el = page.locator("text=Cadastro de equipes").first
            if await el.is_visible(timeout=3000):
                await el.click()
                await page.wait_for_timeout(6000)
                await page.screenshot(path="v4_equipes.png")
                print(f"Docs apos equipes: {len(collected['raw_firestore'])}")
        except Exception as e:
            print(f"Equipes: {e}")

        # ── Tenta "Cadastro de jogadores" ─────────────────────────────────────
        print("Acessando Cadastro de jogadores...")
        await page.goto("https://copafacil.com/user", timeout=20000)
        await page.wait_for_timeout(4000)
        try:
            el = page.locator("text=Cadastro de jogadores").first
            if await el.is_visible(timeout=3000):
                await el.click()
                await page.wait_for_timeout(6000)
                await page.screenshot(path="v4_jogadores.png")
                print(f"Docs apos jogadores: {len(collected['raw_firestore'])}")
        except Exception as e:
            print(f"Jogadores: {e}")

        # ── Salva tudo ────────────────────────────────────────────────────────
        print("\n=== RESUMO FINAL ===")
        print(f"Championships: {len(collected['championships'])}")
        print(f"Teams: {sum(len(v) for v in collected['teams'].values())}")
        print(f"Players: {sum(len(v) for v in collected['players'].values())}")
        print(f"Matches: {sum(len(v) for v in collected['matches'].values())}")
        print(f"Raw docs Firestore: {len(collected['raw_firestore'])}")

        if collected["raw_firestore"]:
            print("\nDocs capturados:")
            for doc in collected["raw_firestore"][:10]:
                print(f"  - {doc.get('_path', '?')} | {list(doc.keys())[:5]}")

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(collected, f, ensure_ascii=False, indent=2, default=str)
        print(f"\nSalvo em {OUTPUT_FILE}")

        await page.wait_for_timeout(5000)
        await browser.close()

    if collected["championships"] or collected["raw_firestore"]:
        print("\nImportando para TVI Firestore...")
        import_to_tvi()
    else:
        print("\nNenhum dado capturado. Verifique as screenshots v4_*.png")

def import_to_tvi():
    import firebase_admin
    from firebase_admin import credentials, firestore as fstore
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        db = fstore.client()
        for champ_id, champ in collected["championships"].items():
            nome = champ.get("name") or champ.get("nome") or champ_id
            slug = re.sub(r"[^a-z0-9]", "_", nome.lower()[:30]) + f"_{champ_id[:6]}"
            db.collection("campeonatos").document(slug).set({
                "nome": nome, "esporte": "futebol", "status": "encerrado",
                "organizadorId": "lalomoraes_migrado", "organizadorNome": "Lalo Moraes",
                "logoUrl": champ.get("logo") or champ.get("logoUrl"),
                "migradoDeCopafacil": True, "copafacilId": champ_id,
            })
            print(f"  Criado: {nome}")
        print("Importacao OK!")
    except Exception as e:
        print(f"Erro importacao: {e}")

if __name__ == "__main__":
    asyncio.run(run())
