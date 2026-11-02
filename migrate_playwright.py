"""
migrate_copafacil_playwright.py
================================
Usa Playwright para abrir o browser REAL da CopáFácil, logar com as credenciais,
navegar por cada campeonato e interceptar todas as chamadas Firestore/RTDB.

Os dados interceptados são salvos em JSON e depois importados no Firestore do TVI News.

USO:
    python migrate_copafacil_playwright.py
"""

import asyncio
import json
import os
import re
import time
from pathlib import Path
from datetime import datetime

# ─── CONFIGURAÇÃO ────────────────────────────────────────────────────────────
COPAFACIL_URL = "https://copafacil.com/user"
COPAFACIL_EMAIL = "lalomoraes@copafacil.com"
COPAFACIL_SENHA = "L@lO2@25"

# Arquivo de saída com todos os dados interceptados
OUTPUT_FILE = "copafacil_data.json"
SERVICE_ACCOUNT = "tvi-news-service-account.json"

# ─── INTERCEPTAÇÃO ───────────────────────────────────────────────────────────

intercepted_data = {
    "championships": {},   # id → dados
    "teams": {},           # championshipId → {teamId → dados}
    "players": {},         # teamId → [jogadores]
    "matches": {},         # championshipId → {matchId → dados}
    "events": {},          # matchId → [eventos/lances]
    "classifications": {}, # championshipId → [classificação]
    "raw_requests": [],    # todos os requests crus para debug
}

def extract_firestore_data(url: str, body: dict) -> None:
    """Extrai e organiza dados de chamadas Firestore."""
    
    # Salva request bruto para debug
    intercepted_data["raw_requests"].append({
        "url": url[:200],
        "timestamp": datetime.now().isoformat(),
        "keys": list(body.keys()) if isinstance(body, dict) else str(type(body))
    })
    
    # Processa documentos Firestore
    if "documents" in body:
        for doc in body.get("documents", []):
            parse_firestore_doc(doc)
    
    # Processa resposta de query (lista de resultados)
    if isinstance(body, list):
        for item in body:
            if isinstance(item, dict) and "document" in item:
                parse_firestore_doc(item["document"])
    
    # Processa documento único
    if "name" in body and "fields" in body:
        parse_firestore_doc(body)


def parse_firestore_doc(doc: dict) -> None:
    """Parseia um documento Firestore e salva no lugar certo."""
    if not doc or "name" not in doc:
        return
    
    name = doc["name"]  # projects/copafacil-web/databases/(default)/documents/championships/abc123
    fields = doc.get("fields", {})
    data = firestore_to_dict(fields)
    data["_firestore_id"] = name.split("/")[-1]
    data["_firestore_path"] = name
    
    parts = name.split("/documents/")[-1].split("/")
    
    # Organiza por coleção
    if len(parts) >= 2:
        collection = parts[0]
        doc_id = parts[1]
        
        if collection in ("championships", "campeonatos", "c"):
            intercepted_data["championships"][doc_id] = data
            print(f"  📋 Championship: {data.get('name', data.get('nome', doc_id))}")
        
        elif collection == "teams" or (len(parts) >= 4 and parts[2] == "teams"):
            champ_id = parts[1] if len(parts) >= 4 else "unknown"
            team_id = parts[3] if len(parts) >= 4 else doc_id
            if champ_id not in intercepted_data["teams"]:
                intercepted_data["teams"][champ_id] = {}
            intercepted_data["teams"][champ_id][team_id] = data
            print(f"  👕 Team: {data.get('name', data.get('nome', team_id))}")
        
        elif collection == "players" or (len(parts) >= 4 and parts[2] in ("players", "jogadores")):
            team_id = parts[1] if len(parts) >= 4 else "unknown"
            if team_id not in intercepted_data["players"]:
                intercepted_data["players"][team_id] = []
            intercepted_data["players"][team_id].append(data)
            print(f"  👤 Player: {data.get('name', data.get('nome', ''))}")
        
        elif collection in ("matches", "games", "partidas", "jogos") or \
             (len(parts) >= 4 and parts[2] in ("matches", "games", "partidas")):
            champ_id = parts[1] if len(parts) >= 4 else "unknown"
            match_id = parts[3] if len(parts) >= 4 else doc_id
            if champ_id not in intercepted_data["matches"]:
                intercepted_data["matches"][champ_id] = {}
            intercepted_data["matches"][champ_id][match_id] = data
        
        elif len(parts) >= 6 and parts[4] in ("events", "lances", "eventos"):
            match_id = parts[3]
            if match_id not in intercepted_data["events"]:
                intercepted_data["events"][match_id] = []
            intercepted_data["events"][match_id].append(data)


def firestore_to_dict(fields: dict) -> dict:
    """Converte campos Firestore para Python dict."""
    result = {}
    for key, value in fields.items():
        result[key] = parse_firestore_value(value)
    return result


def parse_firestore_value(value):
    """Converte um valor Firestore para Python."""
    if not isinstance(value, dict):
        return value
    
    if "stringValue" in value:
        return value["stringValue"]
    elif "integerValue" in value:
        return int(value["integerValue"])
    elif "doubleValue" in value:
        return float(value["doubleValue"])
    elif "booleanValue" in value:
        return value["booleanValue"]
    elif "nullValue" in value:
        return None
    elif "timestampValue" in value:
        return value["timestampValue"]
    elif "mapValue" in value:
        return firestore_to_dict(value["mapValue"].get("fields", {}))
    elif "arrayValue" in value:
        return [parse_firestore_value(v) for v in value["arrayValue"].get("values", [])]
    elif "referenceValue" in value:
        return value["referenceValue"]
    return value


async def intercept_response(response) -> None:
    """Intercepta respostas HTTP do browser."""
    url = response.url
    
    # Só processa chamadas Firestore e RTDB
    if "firestore.googleapis.com" not in url and "firebaseio.com" not in url:
        return
    
    try:
        status = response.status
        if status not in (200, 201):
            return
        
        content_type = response.headers.get("content-type", "")
        if "json" not in content_type:
            return
        
        body = await response.json()
        print(f"  🔍 Interceptou: {url[:80]}... ({len(str(body))} bytes)")
        extract_firestore_data(url, body)
        
    except Exception as e:
        pass  # Silencioso para não poluir output


async def navegar_campeonato(page, champ_name: str, champ_index: int) -> None:
    """Navega para o campeonato pelo índice na lista."""
    print(f"\n🏆 Navegando para: {champ_name}")
    
    # Aguarda renderização do Flutter
    await page.wait_for_timeout(2000)
    
    try:
        # Clica no campeonato pela posição
        # Flutter renderiza em canvas, mas pode ter elementos clicáveis
        await page.wait_for_timeout(1000)
        
        # Tenta clicar no item da lista de campeonatos
        # A CopáFácil usa Flutter web, então usa coordenadas ou acessibilidade
        body = await page.evaluate("""() => {
            // Tenta encontrar o campeonato pelo texto
            const walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT);
            let node;
            while(node = walker.nextNode()) {
                if (node.textContent.includes(arguments[0])) {
                    return node.parentElement ? node.parentElement.getBoundingClientRect() : null;
                }
            }
            return null;
        }""", champ_name[:10])
        
    except:
        pass
    
    # Aguarda mais carregamento de dados
    await page.wait_for_timeout(3000)


async def run_migration():
    """Função principal de migração."""
    from playwright.async_api import async_playwright
    
    print("🚀 Iniciando migração via Playwright\n")
    
    async with async_playwright() as p:
        # Abre browser visível para poder logar
        browser = await p.chromium.launch(
            headless=False,  # Visível para ver o que acontece
            slow_mo=500,     # Devagar para dar tempo de renderizar
        )
        
        context = await browser.new_context(
            viewport={"width": 1280, "height": 900},
            user_agent="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        )
        
        page = await context.new_page()
        
        # Intercepta TODAS as respostas HTTP
        page.on("response", lambda r: asyncio.ensure_future(intercept_response(r)))
        
        print("🌐 Abrindo CopáFácil...")
        await page.goto(COPAFACIL_URL, wait_until="networkidle", timeout=60000)
        await page.wait_for_timeout(5000)  # Flutter precisa de tempo para inicializar
        
        print("🔐 Fazendo login...")
        
        # O Flutter web renderiza em canvas - precisamos usar evaluate para interagir
        # Primeiro tenta via campos HTML normais
        try:
            # Espera campo de email aparecer
            await page.wait_for_selector('input[type="email"]', timeout=10000)
            await page.fill('input[type="email"]', COPAFACIL_EMAIL)
            await page.fill('input[type="password"]', COPAFACIL_SENHA)
            await page.click('button[type="submit"]')
        except:
            # Flutter canvas - usa keyboard navigation
            print("  → Usando teclado para navegar (Flutter canvas)")
            await page.keyboard.press("Tab")
            await page.keyboard.type(COPAFACIL_EMAIL)
            await page.keyboard.press("Tab")
            await page.keyboard.type(COPAFACIL_SENHA)
            await page.keyboard.press("Enter")
        
        print("  ⏳ Aguardando login carregar...")
        await page.wait_for_timeout(8000)
        
        # Salva screenshot para verificar
        await page.screenshot(path="login_result.png")
        print("  📸 Screenshot salva: login_result.png")
        
        # Lista de campeonatos conhecidos para navegar
        championships_to_visit = [
            "Copa TVitapê 2026",
            "Varzeano Itapetininga 2026", 
            "Copa TVitapê 2025",
            "Varzeano Itapetininga 2025",
        ]
        
        print(f"\n📋 Navegando por {len(championships_to_visit)} campeonatos...")
        
        # Aguarda dados iniciais carregarem (a lista de campeonatos)
        await page.wait_for_timeout(5000)
        await page.screenshot(path="after_login.png")
        
        # Navega pela página de campeonatos clicando em cada um
        for i, champ_name in enumerate(championships_to_visit):
            print(f"\n[{i+1}/{len(championships_to_visit)}] Buscando: {champ_name}")
            
            # Volta para a lista de campeonatos
            await page.goto(COPAFACIL_URL, wait_until="networkidle", timeout=30000)
            await page.wait_for_timeout(4000)
            
            # Tenta clicar via JavaScript (Flutter expõe alguns elementos acessíveis)
            clicked = await page.evaluate(f"""
                () => {{
                    // Tenta via semantics do Flutter
                    const els = document.querySelectorAll('[aria-label], [role]');
                    for (const el of els) {{
                        const text = el.textContent || el.getAttribute('aria-label') || '';
                        if (text.includes('{champ_name[:15]}')) {{
                            el.click();
                            return true;
                        }}
                    }}
                    // Tenta via todos elementos com texto
                    const all = document.querySelectorAll('*');
                    for (const el of all) {{
                        if (el.children.length === 0 && el.textContent.includes('{champ_name[:10]}')) {{
                            el.click();
                            return true;
                        }}
                    }}
                    return false;
                }}
            """)
            
            if clicked:
                print(f"  ✅ Clicou no campeonato")
            else:
                print(f"  ⚠️ Não conseguiu clicar - aguardando dados da lista...")
            
            # Aguarda dados carregarem
            await page.wait_for_timeout(5000)
            await page.screenshot(path=f"champ_{i}.png")
            
            print(f"  📸 Screenshot: champ_{i}.png")
            print(f"  📊 Dados coletados até agora:")
            print(f"     Championships: {len(intercepted_data['championships'])}")
            print(f"     Teams: {sum(len(v) for v in intercepted_data['teams'].values())}")
            print(f"     Players: {sum(len(v) for v in intercepted_data['players'].values())}")
            print(f"     Matches: {sum(len(v) for v in intercepted_data['matches'].values())}")
            print(f"     Requests interceptados: {len(intercepted_data['raw_requests'])}")
        
        # Aguarda mais um pouco para garantir todos os dados
        await page.wait_for_timeout(3000)
        
        print(f"\n💾 Salvando dados interceptados em {OUTPUT_FILE}...")
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(intercepted_data, f, ensure_ascii=False, indent=2, default=str)
        
        print(f"✅ Dados salvos!")
        print(f"\n📊 RESUMO FINAL:")
        print(f"   Championships interceptados: {len(intercepted_data['championships'])}")
        print(f"   Teams: {sum(len(v) for v in intercepted_data['teams'].values())}")
        print(f"   Players: {sum(len(v) for v in intercepted_data['players'].values())}")
        print(f"   Matches: {sum(len(v) for v in intercepted_data['matches'].values())}")
        print(f"   Events/Lances: {sum(len(v) for v in intercepted_data['events'].values())}")
        print(f"   Total requests: {len(intercepted_data['raw_requests'])}")
        
        # Pergunta se pode fechar
        print("\n⏳ Fechando browser em 5 segundos...")
        await page.wait_for_timeout(5000)
        await browser.close()
    
    # Importa para o Firestore do TVI se tiver dados
    if intercepted_data["championships"] or intercepted_data["raw_requests"]:
        print("\n🔥 Importando para o Firestore do TVI News...")
        await import_to_firestore()
    else:
        print("\n⚠️ Nenhum dado foi interceptado.")
        print("   Verifique as screenshots login_result.png e after_login.png")


async def import_to_firestore():
    """Importa os dados para o Firestore do TVI News."""
    try:
        import firebase_admin
        from firebase_admin import credentials, firestore as fs_admin
        
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred, {"projectId": "tvi-news"})
        db = fs_admin.client()
        
        championships = intercepted_data.get("championships", {})
        print(f"  📋 Importando {len(championships)} campeonatos...")
        
        for champ_id, champ_data in championships.items():
            nome = champ_data.get("name") or champ_data.get("nome") or champ_data.get("title") or champ_id
            
            # Cria documento do campeonato
            tvi_id = re.sub(r'[^a-z0-9_]', '_', nome.lower()[:30]) + f"_{champ_id[:6]}"
            
            doc_data = {
                "nome": nome,
                "descricao": champ_data.get("description") or champ_data.get("descricao") or "",
                "esporte": "futebol",
                "status": "encerrado",
                "organizadorId": "lalomoraes_migrado",
                "organizadorNome": "Lalo Moraes",
                "logoUrl": champ_data.get("logo") or champ_data.get("logoUrl") or champ_data.get("image"),
                "migradoDeCopafacil": True,
                "copafacilId": champ_id,
                "criadoEm": fs_admin.SERVER_TIMESTAMP,
            }
            
            db.collection("campeonatos").document(tvi_id).set(doc_data)
            print(f"  ✅ Campeonato criado: {nome} → {tvi_id}")
            
            # Times do campeonato
            teams = intercepted_data.get("teams", {}).get(champ_id, {})
            for team_id, team_data in teams.items():
                nome_time = team_data.get("name") or team_data.get("nome") or team_id
                db.collection("campeonatos").document(tvi_id).collection("times").document(team_id).set({
                    "campeonatoId": tvi_id,
                    "nome": nome_time,
                    "logoUrl": team_data.get("logo") or team_data.get("logoUrl"),
                    "categoria": team_data.get("category") or team_data.get("categoria"),
                    "responsavelNome": team_data.get("manager") or team_data.get("responsavel") or "Responsável",
                    "organizadorId": "lalomoraes_migrado",
                    "criadoEm": fs_admin.SERVER_TIMESTAMP,
                })
            
            # Partidas do campeonato
            matches = intercepted_data.get("matches", {}).get(champ_id, {})
            for match_id, match_data in matches.items():
                db.collection("campeonatos").document(tvi_id).collection("partidas").document(match_id).set({
                    "campeonatoId": tvi_id,
                    "timeANome": match_data.get("homeTeam") or match_data.get("teamA") or "Time A",
                    "timeBNome": match_data.get("awayTeam") or match_data.get("teamB") or "Time B",
                    "placarA": match_data.get("homeScore") or match_data.get("scoreA") or 0,
                    "placarB": match_data.get("awayScore") or match_data.get("scoreB") or 0,
                    "status": "encerrada",
                    "copafacilId": match_id,
                    "criadoEm": fs_admin.SERVER_TIMESTAMP,
                })
        
        print("\n✅ IMPORTAÇÃO CONCLUÍDA! Abra o app TVI para ver os campeonatos.")
        
    except Exception as e:
        print(f"\n❌ Erro na importação: {e}")
        print("   Os dados foram salvos em copafacil_data.json para análise manual.")


if __name__ == "__main__":
    asyncio.run(run_migration())
