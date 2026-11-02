"""
migrate_v2.py
=============
Versão 2 - usa CDP para interceptar WebSockets (Firestore gRPC-web)
e clica nos elementos corretos do Flutter.
"""

import asyncio
import json
import re
import base64
import struct
from pathlib import Path
from datetime import datetime

OUTPUT_FILE = "copafacil_data.json"
SERVICE_ACCOUNT = "tvi-news-service-account.json"

COPAFACIL_EMAIL = "lalomoraes@copafacil.com"
COPAFACIL_SENHA = "L@lO2@25"

# Dados coletados
data = {
    "championships": {},
    "teams": {},
    "players": {},
    "matches": {},
    "events": {},
    "raw_firestore": [],  # todos docs crus
}


def parse_value(v):
    if not isinstance(v, dict):
        return v
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
    if not doc or "name" not in doc:
        return
    name = doc["name"]
    fields = {k: parse_value(v) for k, v in doc.get("fields", {}).items()}
    fields["_id"] = name.split("/")[-1]
    fields["_path"] = name
    
    parts = name.split("/documents/")[-1].split("/") if "/documents/" in name else []
    data["raw_firestore"].append(fields)
    
    if not parts:
        return
    
    col = parts[0]
    doc_id = parts[1] if len(parts) > 1 else fields["_id"]
    
    nome = fields.get("name") or fields.get("nome") or fields.get("title") or doc_id
    
    if col in ("championships", "campeonatos"):
        data["championships"][doc_id] = fields
        print(f"  [CAMP] {nome}")
    elif col in ("teams", "equipes") or (len(parts) >= 4 and parts[2] in ("teams","equipes")):
        champ_id = parts[1] if len(parts) >= 4 else "unknown"
        team_id = parts[3] if len(parts) >= 4 else doc_id
        data["teams"].setdefault(champ_id, {})[team_id] = fields
        print(f"  [TIME] {nome}")
    elif col in ("players", "jogadores") or (len(parts) >= 4 and parts[2] in ("players","jogadores")):
        team_id = parts[1] if len(parts) >= 4 else "unknown"
        data["players"].setdefault(team_id, []).append(fields)
        print(f"  [JOG]  {nome}")
    elif col in ("matches", "partidas", "games", "jogos") or (len(parts) >= 4 and parts[2] in ("matches","partidas","games")):
        champ_id = parts[1] if len(parts) >= 4 else "unknown"
        match_id = parts[3] if len(parts) >= 4 else doc_id
        data["matches"].setdefault(champ_id, {})[match_id] = fields
    elif len(parts) >= 6 and parts[4] in ("events", "lances", "eventos"):
        match_id = parts[3]
        data["events"].setdefault(match_id, []).append(fields)


def process_response_body(body_text, url):
    """Processa corpo de resposta HTTP (JSON do Firestore REST)."""
    try:
        body = json.loads(body_text)
        # Lista de documentos
        if isinstance(body, list):
            for item in body:
                if isinstance(item, dict):
                    if "document" in item:
                        parse_doc(item["document"])
                    elif "name" in item and "fields" in item:
                        parse_doc(item)
        elif isinstance(body, dict):
            if "documents" in body:
                for doc in body["documents"]:
                    parse_doc(doc)
            elif "name" in body and "fields" in body:
                parse_doc(body)
    except Exception as e:
        pass


async def run():
    from playwright.async_api import async_playwright

    print("Abrindo browser...")

    async with async_playwright() as p:
        browser = await p.chromium.launch(headless=False, slow_mo=300)
        context = await browser.new_context(viewport={"width": 1400, "height": 900})
        page = await context.new_page()

        # Intercepta respostas HTTP normais (Firestore REST)
        async def on_response(response):
            url = response.url
            if "firestore.googleapis.com" not in url:
                return
            try:
                if response.status == 200:
                    body = await response.text()
                    if body and len(body) > 10:
                        process_response_body(body, url)
            except:
                pass

        page.on("response", lambda r: asyncio.ensure_future(on_response(r)))

        # ── Abre site ─────────────────────────────────────────────────────────
        print("Abrindo copafacil.com...")
        await page.goto("https://copafacil.com/user", timeout=60000)
        await page.wait_for_timeout(6000)  # Flutter precisa de tempo

        # ── Login ─────────────────────────────────────────────────────────────
        print("Fazendo login...")
        await page.screenshot(path="step1_inicial.png")

        # Clica no campo "Usuario" pelo placeholder
        try:
            # Tenta via placeholder
            campo_usuario = page.get_by_placeholder("Usuário")
            await campo_usuario.click(timeout=5000)
            await campo_usuario.fill(COPAFACIL_EMAIL)
            print("  Campo usuario preenchido via placeholder")
        except:
            try:
                # Tenta clicar na posicao visual do campo (baseado na screenshot)
                # Campo Usuário fica em ~x=640, y=388
                await page.mouse.click(640, 388)
                await page.wait_for_timeout(500)
                await page.keyboard.type(COPAFACIL_EMAIL)
                print("  Campo usuario preenchido via coordenada")
            except Exception as e:
                print(f"  Erro campo usuario: {e}")

        await page.wait_for_timeout(500)

        try:
            campo_senha = page.get_by_placeholder("Senha")
            await campo_senha.click(timeout=3000)
            await campo_senha.fill(COPAFACIL_SENHA)
            print("  Campo senha preenchido via placeholder")
        except:
            try:
                await page.mouse.click(640, 450)
                await page.wait_for_timeout(500)
                await page.keyboard.type(COPAFACIL_SENHA)
                print("  Campo senha preenchido via coordenada")
            except Exception as e:
                print(f"  Erro campo senha: {e}")

        await page.wait_for_timeout(500)

        # Clica no botao Login
        try:
            btn = page.get_by_role("button", name="Login")
            await btn.click(timeout=3000)
            print("  Botao Login clicado via role")
        except:
            try:
                await page.mouse.click(640, 519)
                print("  Botao Login clicado via coordenada")
            except Exception as e:
                print(f"  Erro botao login: {e}")

        print("Aguardando login...")
        await page.wait_for_timeout(8000)
        await page.screenshot(path="step2_apos_login.png")
        print("Screenshot: step2_apos_login.png")

        # ── Aguarda lista de campeonatos carregar ──────────────────────────────
        print("\nAguardando dados de campeonatos...")
        await page.wait_for_timeout(5000)
        await page.screenshot(path="step3_lista.png")

        print(f"\nDados apos login inicial:")
        print(f"  Championships: {len(data['championships'])}")
        print(f"  Raw docs Firestore: {len(data['raw_firestore'])}")

        # ── Navega para cada campeonato ────────────────────────────────────────
        # Lista de campeonatos com multiplas estrategias de clique
        campanhas = [
            {"nome": "Copa TVitapê 2026", "slug": "copa-tvitape-2026"},
            {"nome": "Varzeano Itapetininga 2026", "slug": "varzeano-itapetininga-2026"},
            {"nome": "Copa TVitapê 2025", "slug": "copa-tvitape-2025"},
            {"nome": "Varzeano Itapetininga 2025", "slug": "varzeano-itapetininga-2025"},
        ]

        for i, camp in enumerate(campanhas):
            print(f"\n[{i+1}/4] Navegando: {camp['nome']}")

            # Tenta navegar diretamente pela URL publica do campeonato
            url_camp = f"https://copafacil.com/c/{camp['slug']}"
            print(f"  URL: {url_camp}")
            await page.goto(url_camp, timeout=30000)
            await page.wait_for_timeout(6000)  # tempo de renderizar

            await page.screenshot(path=f"camp_{i}_visao_geral.png")
            print(f"  Screenshot: camp_{i}_visao_geral.png")

            # Navega pelas abas do campeonato para forcar carregamento de dados
            abas = ["Partidas", "Classificacao", "Artilharia", "Times", "Equipes",
                    "Jogadores", "Tabela", "Resultados", "Grupos"]
            
            for aba in abas:
                try:
                    el = page.get_by_text(aba, exact=False)
                    count = await el.count()
                    if count > 0:
                        await el.first.click(timeout=3000)
                        await page.wait_for_timeout(3000)
                        print(f"    Clicou na aba: {aba}")
                except:
                    pass

            # Coleta dados apos navegar
            print(f"  Dados coletados:")
            print(f"    Championships: {len(data['championships'])}")
            print(f"    Teams: {sum(len(v) for v in data['teams'].values())}")
            print(f"    Matches: {sum(len(v) for v in data['matches'].values())}")
            print(f"    Raw docs: {len(data['raw_firestore'])}")

            # Tenta tambem a aba de partidas antigas
            try:
                await page.goto(url_camp + "/partidas", timeout=15000)
                await page.wait_for_timeout(4000)
            except:
                pass

        # ── Voltando para painel do organizador ────────────────────────────────
        print("\nAcessando painel do organizador...")
        await page.goto("https://copafacil.com/user", timeout=30000)
        await page.wait_for_timeout(5000)

        # Clica em "Cadastro de equipes"
        try:
            await page.get_by_text("Cadastro de equipes").click(timeout=5000)
            await page.wait_for_timeout(5000)
            print("  Acessou Cadastro de equipes")
            await page.screenshot(path="equipes.png")
        except:
            pass

        # Clica em "Cadastro de jogadores"
        try:
            await page.goto("https://copafacil.com/user", timeout=15000)
            await page.wait_for_timeout(3000)
            await page.get_by_text("Cadastro de jogadores").click(timeout=5000)
            await page.wait_for_timeout(5000)
            print("  Acessou Cadastro de jogadores")
            await page.screenshot(path="jogadores.png")
        except:
            pass

        # ── Salva resultados ───────────────────────────────────────────────────
        print(f"\n\nSalvando {len(data['raw_firestore'])} documentos em {OUTPUT_FILE}...")
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2, default=str)

        print("\nRESUMO FINAL:")
        print(f"  Championships: {len(data['championships'])}")
        print(f"  Teams por camp: {dict((k, len(v)) for k,v in data['teams'].items())}")
        print(f"  Players por time: {sum(len(v) for v in data['players'].values())}")
        print(f"  Matches: {sum(len(v) for v in data['matches'].values())}")
        print(f"  Total raw docs Firestore: {len(data['raw_firestore'])}")

        print("\nFechando em 5 segundos...")
        await page.wait_for_timeout(5000)
        await browser.close()

    # Importa se tiver dados
    total = len(data["championships"]) + len(data["raw_firestore"])
    if total > 0:
        print("\nImportando para TVI News Firestore...")
        import_to_tvi()
    else:
        print("\nNenhum dado capturado.")
        print("Verifique as screenshots para ver o que aconteceu.")


def import_to_tvi():
    import firebase_admin
    from firebase_admin import credentials, firestore as fstore

    try:
        cred = credentials.Certificate(SERVICE_ACCOUNT)
        firebase_admin.initialize_app(cred)
        db = fstore.client()
    except Exception as e:
        print(f"Erro ao inicializar Firebase Admin: {e}")
        return

    print(f"Importando {len(data['championships'])} campeonatos...")
    
    for champ_id, champ in data["championships"].items():
        nome = champ.get("name") or champ.get("nome") or champ.get("title") or champ_id
        slug = re.sub(r"[^a-z0-9]", "_", nome.lower()[:30]) + f"_{champ_id[:6]}"
        
        db.collection("campeonatos").document(slug).set({
            "nome": nome,
            "descricao": champ.get("description") or champ.get("descricao") or "",
            "esporte": "futebol",
            "status": "encerrado",
            "organizadorId": "lalomoraes_migrado",
            "organizadorNome": "Lalo Moraes",
            "logoUrl": champ.get("logo") or champ.get("logoUrl") or champ.get("image"),
            "migradoDeCopafacil": True,
            "copafacilId": champ_id,
        })
        print(f"  Campeonato criado: {nome} -> {slug}")

        for team_id, team in data["teams"].get(champ_id, {}).items():
            nome_time = team.get("name") or team.get("nome") or team_id
            db.collection("campeonatos").document(slug).collection("times").document(team_id).set({
                "campeonatoId": slug,
                "nome": nome_time,
                "logoUrl": team.get("logo") or team.get("shield") or team.get("escudo"),
                "categoria": team.get("category") or team.get("categoria"),
                "responsavelNome": team.get("manager") or team.get("responsavel") or "Responsavel",
                "organizadorId": "lalomoraes_migrado",
            })
            
            for jogador in data["players"].get(team_id, []):
                nome_jog = jogador.get("name") or jogador.get("nome") or "Jogador"
                jog_id = jogador.get("_id", nome_jog[:10])
                db.collection("campeonatos").document(slug)\
                  .collection("times").document(team_id)\
                  .collection("jogadores").document(jog_id).set({
                    "campeonatoId": slug,
                    "timeId": team_id,
                    "nome": nome_jog,
                    "numero": jogador.get("number") or jogador.get("numero"),
                    "posicao": jogador.get("position") or jogador.get("posicao"),
                })

        for match_id, match in data["matches"].get(champ_id, {}).items():
            db.collection("campeonatos").document(slug).collection("partidas").document(match_id).set({
                "campeonatoId": slug,
                "timeANome": match.get("homeTeam") or match.get("teamA") or match.get("equipeA") or "Time A",
                "timeBNome": match.get("awayTeam") or match.get("teamB") or match.get("equipeB") or "Time B",
                "placarA": match.get("homeScore") or match.get("scoreA") or match.get("golsA") or 0,
                "placarB": match.get("awayScore") or match.get("scoreB") or match.get("golsB") or 0,
                "status": "encerrada",
                "copafacilId": match_id,
            })

    print("\nImportacao concluida! Abra o app TVI e veja os campeonatos.")


if __name__ == "__main__":
    asyncio.run(run())
