/**
 * fetch_with_token.js
 * Usa o token real do usuario logado para buscar dados do Firestore da CopáFácil
 * e importar para o TVI News.
 */

const https = require('https');
const admin = require('firebase-admin');

const TOKEN = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjgwMWQ0YTIwNzMwN2I0ZjM1NmFjZGI4NWNhNzE3ZWU3YmEwZGJmN2UiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vY29wYWZhY2lsLXdlYiIsImF1ZCI6ImNvcGFmYWNpbC13ZWIiLCJhdXRoX3RpbWUiOjE3ODc3MDMxMjcsInVzZXJfaWQiOiJPUU1sN2V1STZrVGpQdTlUZEg2YzNOam0ySHcxIiwic3ViIjoiT1FNbDdldUk2a1RqUHU5VGRINmMzTmptMkh3MSIsImlhdCI6MTc5MDg4NTYyNSwiZXhwIjoxNzkwODg5MjI1LCJlbWFpbCI6ImxhbG9tb3JhZXNAY29wYWZhY2lsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJsYWxvbW9yYWVzQGNvcGFmYWNpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.Fno9xwTmQEIQF0CH2NJRz8Y2IdS23JitrcUq2K_Iuzj7VzAkMDP8S2K1ojFSJF7q2A3Tc-ZiQ2OQLOIzKEIYyQPRKqFro36qoCpBXKQRSGYfSwFl7sb0An-g9GDD-SxjV9ob0O_72ctxajLqhQs80rfJiYg1lAipl69W-qk70r-1jmlFcTwFLojVYlQQyDadZrJbDWAGm9tw5vJVjJHvVaBhfpZKx4V0IZ1KNwZd633rJ0h7AVmRmbZhWGu8k0-9HYOSlYbKN7kOm5I2q2fElHCmPCLBpn9K8OF4s4QgEB2O6nYj-qYb7D8TVIbr95IWbqB81l8EN-OdA1m32XO8ow";

const UID = "OQMl7euI6kTjPu9TdH6c3Njm2Hw1";
const PROJECT = "copafacil-web";
const FS_BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

// Dados coletados
const dados = {
  campeonatos: [],
  times: [],
  jogadores: [],
  partidas: [],
  lances: [],
};

// ── Helpers ───────────────────────────────────────────────────────────────────

function parseValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.doubleValue !== undefined) return parseFloat(v.doubleValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.nullValue !== undefined) return null;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, vv]) => [k, parseValue(vv)]));
  if (v.arrayValue) return (v.arrayValue.values || []).map(parseValue);
  if (v.referenceValue !== undefined) return v.referenceValue;
  return null;
}

function docToObj(doc) {
  if (!doc || !doc.fields) return {};
  const obj = Object.fromEntries(Object.entries(doc.fields).map(([k, v]) => [k, parseValue(v)]));
  obj._id = doc.name.split('/').pop();
  obj._path = doc.name;
  return obj;
}

function fsGet(path) {
  return new Promise((resolve) => {
    const url = `${FS_BASE}/${path}?pageSize=500`;
    const req = https.request(url, {
      headers: { 'Authorization': `Bearer ${TOKEN}` }
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const json = JSON.parse(data);
          resolve({ status: res.statusCode, body: json });
        } catch(e) {
          resolve({ status: res.statusCode, body: null });
        }
      });
    });
    req.on('error', () => resolve({ status: 0, body: null }));
    req.end();
  });
}

function fsQuery(collectionId, fieldFilter) {
  return new Promise((resolve) => {
    const body = JSON.stringify({
      structuredQuery: {
        from: [{ collectionId }],
        where: fieldFilter ? {
          fieldFilter: {
            field: { fieldPath: fieldFilter.field },
            op: 'EQUAL',
            value: { stringValue: fieldFilter.value }
          }
        } : undefined,
        limit: 500
      }
    });
    const url = `${FS_BASE}:runQuery`;
    const req = https.request(url, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(body)
      }
    }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          const arr = JSON.parse(data);
          const docs = (Array.isArray(arr) ? arr : []).filter(x => x.document).map(x => docToObj(x.document));
          resolve(docs);
        } catch(e) {
          resolve([]);
        }
      });
    });
    req.on('error', () => resolve([]));
    req.write(body);
    req.end();
  });
}

// ── Main ──────────────────────────────────────────────────────────────────────

async function main() {
  console.log('Buscando dados com token do usuario logado...');
  console.log(`UID: ${UID}\n`);

  // 1. Tenta todas as colecoes de campeonatos com todos os campos possíveis
  const colecoesCamp = ['championships', 'campeonatos', 'tournaments'];
  const camposUID = ['uid', 'userId', 'organizerId', 'organizadorId', 'ownerId', 'creatorId', 'adminId'];

  let campeonatosEncontrados = [];
  let colecaoUsada = '';

  for (const col of colecoesCamp) {
    // Tenta sem filtro primeiro
    const { status, body } = await fsGet(col);
    console.log(`GET ${col}: status=${status}, docs=${body?.documents?.length ?? 0}`);

    if (body?.documents?.length > 0) {
      const todos = body.documents.map(docToObj);
      console.log(`  Campos do 1o doc: ${Object.keys(todos[0]).join(', ')}`);

      // Filtra pelos do usuario
      const meus = todos.filter(d => Object.values(d).includes(UID));
      if (meus.length > 0) {
        console.log(`  → ${meus.length} campeonatos do usuario!`);
        campeonatosEncontrados = meus;
        colecaoUsada = col;
        break;
      } else {
        console.log(`  → Todos: ${todos.length}, nenhum filtrado por UID`);
        console.log(`  → Amostra valores: ${JSON.stringify(todos[0]).substring(0, 200)}`);
        // Usa todos mesmo assim se nao tiver nada melhor
        if (campeonatosEncontrados.length === 0) {
          campeonatosEncontrados = todos;
          colecaoUsada = col;
        }
      }
    }

    // Tenta com filtro por campo
    for (const campo of camposUID) {
      const docs = await fsQuery(col, { field: campo, value: UID });
      if (docs.length > 0) {
        console.log(`  QUERY ${col} onde ${campo}==${UID}: ${docs.length} docs!`);
        campeonatosEncontrados = docs;
        colecaoUsada = col;
        break;
      }
    }
    if (campeonatosEncontrados.length > 0 && colecaoUsada === col) break;
  }

  console.log(`\nTotal campeonatos: ${campeonatosEncontrados.length}`);
  campeonatosEncontrados.forEach(c => {
    const nome = c.name || c.nome || c.title || c._id;
    console.log(`  - ${c._id}: ${nome}`);
  });

  dados.campeonatos = campeonatosEncontrados;

  // 2. Para cada campeonato, busca times, jogadores, partidas, lances
  for (const camp of campeonatosEncontrados) {
    const campId = camp._id;
    const nome = camp.name || camp.nome || camp.title || campId;
    console.log(`\nBuscando sub-dados de: ${nome} (${campId})`);

    // Times
    for (const colTime of ['teams', 'equipes', 'times']) {
      const { body } = await fsGet(`${colecaoUsada}/${campId}/${colTime}`);
      if (body?.documents?.length > 0) {
        const times = body.documents.map(d => ({ ...docToObj(d), _campId: campId }));
        dados.times.push(...times);
        console.log(`  ${colTime}: ${times.length} times`);

        // Jogadores de cada time
        for (const time of times) {
          for (const colJog of ['players', 'jogadores']) {
            const { body: jBody } = await fsGet(`${colecaoUsada}/${campId}/${colTime}/${time._id}/${colJog}`);
            if (jBody?.documents?.length > 0) {
              const jogs = jBody.documents.map(d => ({ ...docToObj(d), _timeId: time._id, _campId: campId }));
              dados.jogadores.push(...jogs);
              console.log(`    ${time.name || time.nome || time._id}: ${jogs.length} jogadores`);
            }
          }
        }
        break;
      }
    }

    // Partidas
    for (const colPart of ['matches', 'partidas', 'games', 'jogos']) {
      const { body } = await fsGet(`${colecaoUsada}/${campId}/${colPart}`);
      if (body?.documents?.length > 0) {
        const parts = body.documents.map(d => ({ ...docToObj(d), _campId: campId }));
        dados.partidas.push(...parts);
        console.log(`  ${colPart}: ${parts.length} partidas`);

        // Lances de cada partida
        for (const part of parts) {
          for (const colLance of ['events', 'lances', 'eventos']) {
            const { body: lBody } = await fsGet(`${colecaoUsada}/${campId}/${colPart}/${part._id}/${colLance}`);
            if (lBody?.documents?.length > 0) {
              const lances = lBody.documents.map(d => ({ ...docToObj(d), _partidaId: part._id, _campId: campId }));
              dados.lances.push(...lances);
            }
          }
        }
        break;
      }
    }
  }

  // 3. Resumo
  console.log('\n\n=== RESUMO FINAL ===');
  console.log(`Campeonatos: ${dados.campeonatos.length}`);
  console.log(`Times: ${dados.times.length}`);
  console.log(`Jogadores: ${dados.jogadores.length}`);
  console.log(`Partidas: ${dados.partidas.length}`);
  console.log(`Lances: ${dados.lances.length}`);

  // Salva JSON para debug
  require('fs').writeFileSync('copafacil_data.json', JSON.stringify(dados, null, 2), 'utf-8');
  console.log('\nDados salvos em copafacil_data.json');

  // 4. Importa para TVI News Firestore
  if (dados.campeonatos.length > 0) {
    await importarParaTVI();
  } else {
    console.log('\nNenhum campeonato encontrado. Verifique copafacil_data.json para diagnóstico.');
  }
}

async function importarParaTVI() {
  console.log('\nImportando para TVI News Firestore...');

  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  for (const camp of dados.campeonatos) {
    const nome = camp.name || camp.nome || camp.title || camp._id;
    const slug = nome.toLowerCase()
      .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9]+/g, '_').replace(/^_|_$/g, '')
      + '_' + camp._id.substring(0, 6);

    await db.collection('campeonatos').doc(slug).set({
      nome,
      descricao: camp.description || camp.descricao || '',
      esporte: camp.sport || camp.esporte || camp.modality || 'futebol',
      status: 'encerrado',
      organizadorId: 'lalomoraes_migrado',
      organizadorNome: 'Lalo Moraes',
      logoUrl: camp.logo || camp.logoUrl || camp.image || camp.imageUrl || null,
      migradoDeCopafacil: true,
      copafacilId: camp._id,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ Campeonato: ${nome} → ${slug}`);

    // Times
    const times = dados.times.filter(t => t._campId === camp._id);
    for (const time of times) {
      const nomeTime = time.name || time.nome || time._id;
      await db.collection('campeonatos').doc(slug).collection('times').doc(time._id).set({
        campeonatoId: slug,
        nome: nomeTime,
        logoUrl: time.logo || time.logoUrl || time.shield || time.escudo || null,
        categoria: time.category || time.categoria || null,
        responsavelNome: time.manager || time.responsavel || time.representative || 'Responsável',
        organizadorId: 'lalomoraes_migrado',
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      // Jogadores do time
      const jogadores = dados.jogadores.filter(j => j._timeId === time._id);
      for (const jog of jogadores) {
        await db.collection('campeonatos').doc(slug)
          .collection('times').doc(time._id)
          .collection('jogadores').doc(jog._id).set({
            campeonatoId: slug,
            timeId: time._id,
            nome: jog.name || jog.nome || 'Jogador',
            apelido: jog.nickname || jog.apelido || null,
            numero: jog.number || jog.numero || jog.shirt || null,
            posicao: jog.position || jog.posicao || null,
            fotoUrl: jog.photo || jog.fotoUrl || jog.image || null,
            criadoEm: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
      if (jogadores.length > 0) console.log(`    ${nomeTime}: ${jogadores.length} jogadores`);
    }
    if (times.length > 0) console.log(`    ${times.length} times migrados`);

    // Partidas
    const partidas = dados.partidas.filter(p => p._campId === camp._id);
    for (const part of partidas) {
      const lances = dados.lances.filter(l => l._partidaId === part._id);
      await db.collection('campeonatos').doc(slug).collection('partidas').doc(part._id).set({
        campeonatoId: slug,
        timeAId: part.homeTeamId || part.teamAId || part.equipeAId || null,
        timeANome: part.homeTeam || part.teamA || part.equipeA || part.mandante || 'Time A',
        timeBId: part.awayTeamId || part.teamBId || part.equipeBId || null,
        timeBNome: part.awayTeam || part.teamB || part.equipeB || part.visitante || 'Time B',
        placarA: parseInt(part.homeScore || part.scoreA || part.golsA || part.placarA || 0),
        placarB: parseInt(part.awayScore || part.scoreB || part.golsB || part.placarB || 0),
        status: 'encerrada',
        dataHora: part.date || part.data || part.dataHora || null,
        local: part.local || part.location || part.venue || null,
        faseId: part.phase || part.fase || part.round || 'geral',
        copafacilId: part._id,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      for (const lance of lances) {
        await db.collection('campeonatos').doc(slug)
          .collection('partidas').doc(part._id)
          .collection('lances').doc(lance._id).set({
            tipo: lance.type || lance.tipo || 'ocorrencia',
            jogadorNome: lance.playerName || lance.jogadorNome || lance.player || null,
            timeId: lance.teamId || lance.equipeId || null,
            minuto: parseInt(lance.minute || lance.minuto || 0),
            descricao: lance.description || lance.descricao || null,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });
      }
    }
    if (partidas.length > 0) console.log(`    ${partidas.length} partidas migradas`);
  }

  console.log('\n✓ Importação concluída! Abra o app TVI e veja os campeonatos.');
  process.exit(0);
}

main().catch(e => {
  console.error('Erro:', e.message);
  process.exit(1);
});
