// ============================================================
// COLE ESTE CODIGO NO CONSOLE DO CHROME (F12 > Console)
// Ele vai baixar um arquivo JSON com TODOS os dados da CopáFácil
// ============================================================

(async function exportarCopafacil() {
  console.log("Iniciando exportacao...");
  
  const resultado = {
    campeonatos: [],
    times: [],
    jogadores: [],
    partidas: [],
    lances: [],
    timestamp: new Date().toISOString()
  };

  // Pega o token do usuario logado via Firebase interno
  const getToken = async () => {
    try {
      // Tenta via indexedDB do Firebase
      return new Promise((resolve) => {
        const req = indexedDB.open("firebaseLocalStorageDb");
        req.onsuccess = (e) => {
          const db = e.target.result;
          try {
            const tx = db.transaction("firebaseLocalStorage", "readonly");
            const store = tx.objectStore("firebaseLocalStorage");
            const getAllReq = store.getAll();
            getAllReq.onsuccess = () => {
              const items = getAllReq.result;
              const authItem = items.find(i => i.fbase_key && i.fbase_key.includes(":authUser:"));
              if (authItem && authItem.value) {
                resolve(authItem.value.stsTokenManager?.accessToken || null);
              } else {
                resolve(null);
              }
            };
          } catch(e2) { resolve(null); }
        };
        req.onerror = () => resolve(null);
      });
    } catch(e) { return null; }
  };

  const token = await getToken();
  console.log("Token obtido:", token ? "SIM (" + token.substring(0,20) + "...)" : "NAO");

  if (!token) {
    alert("Nao foi possivel obter o token. Certifique-se de estar logado na CopáFácil.");
    return;
  }

  const PROJECT = "copafacil-web";
  const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;
  const headers = { "Authorization": "Bearer " + token, "Content-Type": "application/json" };

  // Funcao para converter valor Firestore
  const val = (v) => {
    if (!v) return null;
    if (v.stringValue !== undefined) return v.stringValue;
    if (v.integerValue !== undefined) return parseInt(v.integerValue);
    if (v.doubleValue !== undefined) return parseFloat(v.doubleValue);
    if (v.booleanValue !== undefined) return v.booleanValue;
    if (v.nullValue !== undefined) return null;
    if (v.timestampValue !== undefined) return v.timestampValue;
    if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,v2])=>[k,val(v2)]));
    if (v.arrayValue) return (v.arrayValue.values||[]).map(val);
    if (v.referenceValue !== undefined) return v.referenceValue;
    return v;
  };

  const docToObj = (doc) => {
    if (!doc || !doc.fields) return {};
    const obj = Object.fromEntries(Object.entries(doc.fields).map(([k,v2])=>[k,val(v2)]));
    obj._id = doc.name.split("/").pop();
    obj._path = doc.name;
    return obj;
  };

  // Funcao para fazer query Firestore
  const query = async (collectionId, filters = [], parentPath = "") => {
    const body = {
      structuredQuery: {
        from: [{ collectionId }],
        limit: 500
      }
    };
    if (filters.length > 0) {
      body.structuredQuery.where = {
        compositeFilter: {
          op: "AND",
          filters: filters.map(([field, op, value]) => ({
            fieldFilter: {
              field: { fieldPath: field },
              op,
              value: typeof value === "string" ? { stringValue: value } : { integerValue: value }
            }
          }))
        }
      };
    }
    const base = parentPath ? `${BASE}/${parentPath}:runQuery` : `${BASE}:runQuery`;
    const r = await fetch(base, { method: "POST", headers, body: JSON.stringify(body) });
    const data = await r.json();
    return (Array.isArray(data) ? data : []).filter(x => x.document).map(x => docToObj(x.document));
  };

  // Funcao para listar colecao
  const list = async (path) => {
    const r = await fetch(`${BASE}/${path}?pageSize=500`, { headers });
    const data = await r.json();
    return (data.documents || []).map(docToObj);
  };

  // ── BUSCA CAMPEONATOS ──────────────────────────────────────────────────────
  console.log("Buscando campeonatos...");
  const uid = JSON.parse(atob(token.split(".")[1].replace(/-/g,"+").replace(/_/g,"/") + "==")).user_id || "";
  console.log("UID:", uid);

  // Tenta varias colecoes e campos
  const colecoesCamp = ["championships", "campeonatos", "tournaments", "torneios"];
  const camposUID = ["uid", "userId", "organizerId", "organizadorId", "ownerId", "creatorId", "authorId"];

  for (const col of colecoesCamp) {
    for (const campo of camposUID) {
      try {
        const docs = await query(col, [[campo, "EQUAL", uid]]);
        if (docs.length > 0) {
          console.log(`ACHEI! ${col} onde ${campo}==${uid}: ${docs.length} campeonatos`);
          resultado.campeonatos.push(...docs.map(d => ({...d, _colecao: col})));
        }
      } catch(e) {}
    }
    // Sem filtro tambem
    try {
      const docs = await list(col);
      if (docs.length > 0) {
        console.log(`${col} SEM FILTRO: ${docs.length} docs`);
        // Filtra os que pertencem ao usuario
        const meus = docs.filter(d => Object.values(d).includes(uid));
        if (meus.length > 0) {
          console.log(`  -> ${meus.length} sao do usuario!`);
          resultado.campeonatos.push(...meus.map(d => ({...d, _colecao: col})));
        } else {
          // Adiciona todos mesmo assim para inspecao
          resultado.campeonatos.push(...docs.map(d => ({...d, _colecao: col})));
          console.log("  (adicionados todos para inspecao)");
        }
      }
    } catch(e) {}
  }

  console.log(`Total campeonatos encontrados: ${resultado.campeonatos.length}`);

  // ── BUSCA TIMES E JOGADORES POR CAMPEONATO ─────────────────────────────────
  for (const camp of resultado.campeonatos) {
    const campId = camp._id;
    const colCamp = camp._colecao || "championships";
    console.log(`Buscando times do campeonato: ${camp.name || camp.nome || campId}`);

    for (const colTime of ["teams", "equipes", "times"]) {
      try {
        const times = await list(`${colCamp}/${campId}/${colTime}`);
        if (times.length > 0) {
          console.log(`  ${colTime}: ${times.length} times`);
          times.forEach(t => { t._campeonatoId = campId; resultado.times.push(t); });

          // Busca jogadores de cada time
          for (const time of times) {
            for (const colJog of ["players", "jogadores"]) {
              try {
                const jogs = await list(`${colCamp}/${campId}/${colTime}/${time._id}/${colJog}`);
                if (jogs.length > 0) {
                  console.log(`    ${time.name||time.nome}: ${jogs.length} jogadores`);
                  jogs.forEach(j => { j._timeId = time._id; j._campeonatoId = campId; resultado.jogadores.push(j); });
                }
              } catch(e) {}
            }
          }
        }
      } catch(e) {}
    }

    // Busca partidas
    for (const colPart of ["matches", "games", "partidas", "jogos"]) {
      try {
        const partidas = await list(`${colCamp}/${campId}/${colPart}`);
        if (partidas.length > 0) {
          console.log(`  ${colPart}: ${partidas.length} partidas`);
          partidas.forEach(p => { p._campeonatoId = campId; resultado.partidas.push(p); });

          // Busca lances de cada partida
          for (const partida of partidas) {
            for (const colLance of ["events", "lances", "eventos"]) {
              try {
                const lances = await list(`${colCamp}/${campId}/${colPart}/${partida._id}/${colLance}`);
                if (lances.length > 0) {
                  lances.forEach(l => { l._partidaId = partida._id; l._campeonatoId = campId; resultado.lances.push(l); });
                }
              } catch(e) {}
            }
          }
        }
      } catch(e) {}
    }
  }

  // ── EXIBE RESUMO ───────────────────────────────────────────────────────────
  console.log("\n=== RESULTADO ===");
  console.log("Campeonatos:", resultado.campeonatos.length);
  console.log("Times:", resultado.times.length);
  console.log("Jogadores:", resultado.jogadores.length);
  console.log("Partidas:", resultado.partidas.length);
  console.log("Lances:", resultado.lances.length);

  // ── BAIXA ARQUIVO JSON ─────────────────────────────────────────────────────
  const blob = new Blob([JSON.stringify(resultado, null, 2)], {type: "application/json"});
  const url = URL.createObjectURL(blob);
  const a = document.createElement("a");
  a.href = url;
  a.download = "copafacil_export.json";
  a.click();
  URL.revokeObjectURL(url);

  console.log("\nArquivo copafacil_export.json baixado!");
  console.log("Salve este arquivo na pasta C:\\Users\\Carlos\\Desktop\\TVI\\");
  return resultado;
})();
