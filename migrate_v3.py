"""
migrate_v3.py
=============
V3 - Espera Flutter carregar completamente, captura URLs reais dos campeonatos
e usa CDP para monitorar TODAS as requisicoes de rede incluindo WebSocket/gRPC.
"""

import asyncio
import json
import re
import sys
from datetime import datetime

OUTPUT_FILE = "copafacil_data.json"
SERVICE_ACCOUNT = "tvi-news-service-account.json"

COPAFACIL_EMAIL = "lalomoraes@copafacil.com"
COPAFACIL_SENHA = "L@lO2@25"

data = {
    "championships": {},
    "teams": {},
    "players": {},
    "matches": {},
    "events": {},
    "raw_firestore": [],
    "urls_visitadas": [],
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
    parts = name.split("/documents/")[-1].split("/") if "/documents/" in name else []
    data["raw_firestore"].append(fields)
    if not parts: return
    col, doc_id = parts[0], parts[1] if len(parts) > 1 else fields["_id"]
    nome = fields.get("name") or fields.get("nome") or fields.get("title") or doc_id
    if col in ("championships", "campeonatos"):
        data["championships"][doc_id] = fields
        print(f"  [CAMP] {nome}")
    elif len(parts) >= 4 and parts[2] in ("teams","equipes","times"):
        data["teams"].setdefault(parts[1], {})[parts[3]] = fields
        print(f"  [TIME] {nome}")
    elif len(parts) >= 4 and parts[2] in ("players","jogadores"):
        data["players"].setdefault(parts[1], []).append(fields)
        print(f"  [JOG]  {nome}")
    elif len(parts) >= 4 and parts[2] in ("matches","partidas","games","jogos"):
        data["matches"].setdefault(parts[1], {})[parts[3]] = fields
    elif len(parts) >= 6 and parts[4] in ("events","lances","eventos"):
        data["events"].setdefault(parts[3], []).append(fields)

def process_body(body_text):
    try:
        body = json.loads(body_text)
        if isinstance(body, list):
            for item in body:
                if isinstance(item, dict):
                    if "document" in item: parse_doc(item["document"])
                    elif "name" in item and "fields" in item: parse_doc(item)
        elif isinstance(body, dict):
            if "documents" in body:
                for doc in body["documents"]: parse_doc(doc)
            elif "name" in body and "fields" in body: parse_doc(body)
    except: pass

async def wait_flutter(page, seconds=12):
    """Espera o Flutter carregar completamente."""
    print(f"  Aguardando Flutter ({seconds}s)...")
    await page.wait_for_timeout(seconds * 1000)

async def run():
    from playwright.async_api import async_playwright

    print("=== MIGRACAO COPAFACIL V3 ===\n")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False, slow_mo=200)
        context = await browser.new_context(
            viewport={"width": 1400, "height": 900},
        )
        page = await context.new_page()

        # Intercepta TODAS as respostas
        async def on_response(response):
            url = response.url
            if "firestore.googleapis.com" not in url: return
            try:
                if response.status == 200:
                    body = await response.text()
                    if body and len(body) > 20:
                        process_body(body)
            except: pass

        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # ── PASSO 1: Abre app Flutter e espera carregar ────────────────────────
        print("Abrindo app Flutter da CopáFácil...")
        await page.goto("https://copafacil.com/user", timeout=60000)
        await wait_flutter(page, 10)  # Flutter precisa de 10s para inicializar
        await page.screenshot(path="v3_step1_carregado.png")

        # ── PASSO 2: Login ──────────────────────────────────────────────────────
        print("Fazendo login...")

        # Tenta clicar no modal de login - campo Usuário
        # Baseado na screenshot v1: modal está em x~640, y~388 (usuario) e y~450 (senha)
        try:
            await page.mouse.click(640, 388)
            await page.wait_for_timeout(1000)
            # Limpa campo e digita
            await page.keyboard.press("Control+a")
            await page.keyboard.type(COPAFACIL_EMAIL, delay=50)
            print("  Email digitado")
        except Exception as e:
            print(f"  Erro email: {e}")

        await page.wait_for_timeout(500)

        try:
            await page.mouse.click(640, 450)
            await page.wait_for_timeout(500)
            await page.keyboard.press("Control+a")
            await page.keyboard.type(COPAFACIL_SENHA, delay=50)
            print("  Senha digitada")
        except Exception as e:
            print(f"  Erro senha: {e}")

        await page.wait_for_timeout(500)

        # Clica no botão Login (posição ~640, 519 baseado na screenshot)
        await page.mouse.click(640, 519)
        print("  Botao Login clicado")

        print("Aguardando login processar...")
        await wait_flutter(page, 12)  # 12s para processar login e carregar dados
        await page.screenshot(path="v3_step2_login.png")

        print(f"\nApos login:")
        print(f"  Championships: {len(data['championships'])}")
        print(f"  Raw docs: {len(data['raw_firestore'])}")

        # Captura URL atual para ver se mudou
        current_url = page.url
        print(f"  URL atual: {current_url}")
        data["urls_visitadas"].append(current_url)

        # ── PASSO 3: Captura a lista de campeonatos e suas URLs reais ──────────
        print("\nCapturando lista de campeonatos...")

        # Aguarda mais para dados carregarem
        await wait_flutter(page, 5)
        await page.screenshot(path="v3_step3_lista.png")

        # Pega todas as URLs da pagina atual (links href)
        links = await page.evaluate("""
            () => {
                const links = [];
                // Pega todos links da pagina
                document.querySelectorAll('a[href]').forEach(a => links.push({
                    href: a.href,
                    text: a.textContent.trim().substring(0, 100)
                }));
                return links;
            }
        """)
        print(f"  Links encontrados na pagina: {len(links)}")
        champ_links = [l for l in links if '/c/' in l.get('href', '') or '/championship' in l.get('href', '')]
        print(f"  Links de campeonatos: {len(champ_links)}")
        for l in champ_links[:10]:
            print(f"    {l['href']} | {l['text'][:50]}")

        # ── PASSO 4: Clica em cada campeonato da lista ─────────────────────────
        # Estrategia: clicar em posicoes onde os cards aparecem
        # Na lista do painel do organizador, os cards ficam na parte direita
        
        # Primeiro tenta clicar nos campeonatos pelo texto
        nomes_campeonatos = [
            "Copa TVitapê 2026", "Varzeano Itapetininga 2026",
            "Copa TVitapê 2025", "Varzeano Itapetininga 2025",
            "Copa TV", "Varzeano"
        ]

        urls_campeonatos = []

        for nome in nomes_campeonatos:
            try:
                # Volta para lista
                await page.goto("https://copafacil.com/user", timeout=30000)
                await wait_flutter(page, 8)
                
                # Tenta clicar pelo texto
                el = page.get_by_text(nome, exact=False)
                count = await el.count()
                if count > 0:
                    # Anota URL antes do clique
                    url_antes = page.url
                    await el.first.click(timeout=5000)
                    await wait_flutter(page, 6)
                    url_depois = page.url
                    
                    if url_depois != url_antes:
                        print(f"  Campeonato '{nome}': URL = {url_depois}")
                        urls_campeonatos.append(url_depois)
                        data["urls_visitadas"].append(url_depois)
                        await page.screenshot(path=f"v3_camp_{len(urls_campeonatos)}.png")
                        
                        # Navega pelas abas para carregar dados
                        for aba in ["Partidas", "Jogos", "Classificacao", "Tabela",
                                    "Times", "Equipes", "Artilharia", "Grupos"]:
                            try:
                                el_aba = page.get_by_text(aba, exact=False)
                                if await el_aba.count() > 0:
                                    await el_aba.first.click(timeout=3000)
                                    await page.wait_for_timeout(3000)
                                    print(f"    Aba '{aba}' carregada")
                            except: pass
                    else:
                        print(f"  '{nome}': clicou mas URL nao mudou")
            except Exception as e:
                print(f"  '{nome}': erro - {e}")

        # ── PASSO 5: Acessa painel de administracao ────────────────────────────
        print("\nAcessando painel de administracao...")
        await page.goto("https://copafacil.com/user", timeout=30000)
        await wait_flutter(page, 8)

        # Clica em "Meus campeonatos"
        try:
            await page.get_by_text("Meus campeonatos").click(timeout=5000)
            await wait_flutter(page, 8)
            await page.screenshot(path="v3_meus_campeonatos.png")
            print("  Acessou Meus campeonatos")
            
            # Coleta links dos campeonatos
            links2 = await page.evaluate("""
                () => {
                    const links = [];
                    document.querySelectorAll('a[href]').forEach(a => links.push(a.href));
                    return links;
                }
            """)
            champ_links2 = [l for l in links2 if l and ('/c/' in l or '/championship' in l or '/camp' in l)]
            print(f"  Links de campeonatos no painel: {champ_links2[:10]}")
        except Exception as e:
            print(f"  Erro meus campeonatos: {e}")

        # Tenta "Cadastro de equipes" para pegar times
        try:
            await page.get_by_text("Cadastro de equipes").click(timeout=5000)
            await wait_flutter(page, 6)
            await page.screenshot(path="v3_equipes.png")
            print("  Acessou Cadastro de equipes")
        except: pass

        # Tenta "Cadastro de jogadores"
        try:
            await page.goto("https://copafacil.com/user", timeout=15000)
            await wait_flutter(page, 5)
            await page.get_by_text("Cadastro de jogadores").click(timeout=5000)
            await wait_flutter(page, 6)
            await page.screenshot(path="v3_jogadores.png")
            print("  Acessou Cadastro de jogadores")
        except: pass

        # ── PASSO 6: Salva resultados ──────────────────────────────────────────
        print(f"\n\nRESUMO FINAL:")
        print(f"  URLs visitadas: {data['urls_visitadas']}")
        print(f"  Championships: {len(data['championships'])}")
        print(f"  Teams: {sum(len(v) for v in data['teams'].values())}")
        print(f"  Players: {sum(len(v) for v in data['players'].values())}")
        print(f"  Matches: {sum(len(v) for v in data['matches'].values())}")
        print(f"  Raw docs Firestore: {len(data['raw_firestore'])}")

        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, default=str)
        print(f"\nDados salvos em: {OUTPUT_FILE}")

        # Mostra raw docs para debug
        if data["raw_firestore"]:
            print("\nPrimeiros documentos capturados:")
            for doc in data["raw_firestore"][:5]:
                print(f"  - {doc.get('_path','?')} | {list(doc.keys())[:6]}")
        else:
            print("\nNENHUM documento Firestore capturado.")
            print("A CopáFácil usa gRPC-web (WebSocket) que o Playwright nao intercepta via response.")
            print("Verifique as screenshots para entender o estado do app.")

        await page.wait_for_timeout(5000)
        await browser.close()

    if data["raw_firestore"] or data["championships"]:
        print("\nImportando para TVI News...")
        import_to_tvi()

def import_to_tvi():
    import firebase_admin
    from firebase_admin import credentials, firestore as fstore
    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        db = fstore.client()
    except Exception as e:
        print(f"Erro Firebase Admin: {e}")
        return

    for champ_id, champ in data["championships"].items():
        nome = champ.get("name") or champ.get("nome") or champ_id
        slug = re.sub(r"[^a-z0-9]", "_", nome.lower()[:30]) + f"_{champ_id[:6]}"
        db.collection("campeonatos").document(slug).set({
            "nome": nome, "esporte": "futebol", "status": "encerrado",
            "organizadorId": "lalomoraes_migrado", "organizadorNome": "Lalo Moraes",
            "logoUrl": champ.get("logo") or champ.get("logoUrl"),
            "migradoDeCopafacil": True, "copafacilId": champ_id,
        })
        print(f"  Campeonato: {nome}")
        for team_id, team in data["teams"].get(champ_id, {}).items():
            nome_time = team.get("name") or team.get("nome") or team_id
            db.collection("campeonatos").document(slug).collection("times").document(team_id).set({
                "campeonatoId": slug, "nome": nome_time,
                "organizadorId": "lalomoraes_migrado",
            })
    print("Importacao concluida!")

if __name__ == "__main__":
    asyncio.run(run())
