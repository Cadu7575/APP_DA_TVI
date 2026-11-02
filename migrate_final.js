/**
 * migrate_final.js
 * Usa credenciais para obter token fresco + IDs dos campeonatos descobertos
 */

const https = require('https');
const admin = require('firebase-admin');
const fs = require('fs');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const EMAIL = 'lalomoraes@copafacil.com';
const SENHA = 'L@lO2@25';
const BASE = 'https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents';

// IDs descobertos via URL do browser
// Adicione os outros abaixo conforme clicar em cada campeonato
const CAMP_IDS_CONHECIDOS = {
  '5fqd2': 'Copa TVitapê 2026',
  // Adicione os outros quando souber:
  // 'OUTRO_ID': 'Varzeano Itapetininga 2026',
  // 'OUTRO_ID': 'Copa TVitapê 2025',
  // 'OUTRO_ID': 'Varzeano Itapetininga 2025',
};

function post(hostname, path, body) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request({ hostname, path, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve(JSON.parse(d)); } catch { resolve({}); } });
    });
    req.on('error', () => resolve({}));
    req.write(data); req.end();
  });
}

function get(path, token) {
  return new Promise(resolve => {
    const url = `${BASE}/${path}?pageSize=500`;
    https.get(url, { headers: { Authorization: `Bearer ${token}` } }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: null }); }
      });
    }).on('error', () => resolve({ status: 0, body: null }));
  });
}

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

const dados = { campeonatos: [], times: [], jogadores: [], partidas: [], lances: [] };

async function fetchSubcollection(token, campCol, campId, subCols) {
  for (const sub of subCols) {
    const { status, body } = await get(`${campCol}/${campId}/${sub}`, token);
    if (status === 200 && body?.documents?.length > 0) {
      return { col: sub, docs: body.documents.map(docToObj) };
    }
  }
  return { col: null, docs: [] };
}

async function main() {
  // 1. Obtém token fresco
  console.log('Obtendo token fresco...');
  const authResp = await post('identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithPassword?key=${API_KEY}`,
    { email: EMAIL, password: SENHA, returnSecureToken: true }
  );

  if (!authResp.idToken) {
    console.error('Falha ao obter token:', JSON.stringify(authResp));
    process.exit(1);
  }
  const TOKEN = authResp.idToken;
  const UID = authResp.localId;
  console.log(`Token OK! UID: ${UID}\n`);

  // 2. Descobre a coleção correta testando com o ID conhecido
  const campCols = ['championships', 'campeonatos', 'c', 'champ', 'tournaments'];
  let campCol = null;

  for (const col of campCols) {
    const { status, body } = await get(`${col}/5fqd2`, TOKEN);
    console.log(`${col}/5fqd2: ${status}`);
    if (status === 200 && body?.fields) {
      campCol = col;
      const camp = docToObj(body);
      console.log(`\n✅ ENCONTRADO em coleção: ${col}`);
      console.log('Campos:', Object.keys(camp).filter(k => !k.startsWith('_')).join(', '));
      console.log('Nome:', camp.name || camp.nome || camp.title);
      dados.campeonatos.push(camp);
      break;
    }
  }

  if (!campCol) {
    console.log('\nNão encontrou com ID direto. Tentando listar coleções conhecidas...');
    
    // Tenta buscar por query usando UID
    for (const col of campCols) {
      for (const campo of ['uid', 'userId', 'organizerId', 'ownerId', 'adminId', 'organizadorId']) {
        const queryBody = JSON.stringify({
          structuredQuery: {
            from: [{ collectionId: col }],
            where: { fieldFilter: { field: { fieldPath: campo }, op: 'EQUAL', value: { stringValue: UID } } },
            limit: 50
          }
        });
        
        await new Promise(resolve => {
          const req = https.request(
            `${BASE}:runQuery`,
            { method: 'POST', headers: { Authorization: `Bearer ${TOKEN}`, 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(queryBody) } },
            res => {
              let d = '';
              res.on('data', c => d += c);
              res.on('end', () => {
                try {
                  const arr = JSON.parse(d);
                  const docs = (Array.isArray(arr) ? arr : []).filter(x => x.document).map(x => docToObj(x.document));
                  if (docs.length > 0) {
                    console.log(`\n✅ QUERY ${col} onde ${campo}==${UID}: ${docs.length} docs!`);
                    docs.forEach(d => console.log(`  ${d._id}: ${d.name || d.nome || d.title}`));
                    campCol = col;
                    dados.campeonatos.push(...docs);
                  }
                } catch {}
                resolve();
              });
            }
          );
          req.write(queryBody); req.end();
        });
        if (campCol) break;
      }
      if (campCol) break;
    }
  }

  // 3. Testa todos os IDs conhecidos
  if (campCol) {
    for (const [id, nome] of Object.entries(CAMP_IDS_CONHECIDOS)) {
      if (!dados.campeonatos.find(c => c._id === id)) {
        const { status, body } = await get(`${campCol}/${id}`, TOKEN);
        if (status === 200 && body?.fields) {
          const camp = docToObj(body);
          dados.campeonatos.push(camp);
          console.log(`✅ Campeonato: ${camp.name || camp.nome || nome}`);
        }
      }
    }
  }

  if (!campCol || dados.campeonatos.length === 0) {
    console.log('\n⚠️  Não conseguiu encontrar os campeonatos via REST API.');
    console.log('O token é válido mas as regras Firestore bloqueiam o acesso externo.');
    console.log('\nPreciso dos IDs dos outros campeonatos. Clique em cada um no browser e me diga a URL.');
    console.log('Exemplo: copafacil.com/XXXX <- esse XXXX é o ID');
    process.exit(0);
  }

  // 4. Busca times, jogadores e partidas de cada campeonato
  for (const camp of dados.campeonatos) {
    const campId = camp._id;
    const nome = camp.name || camp.nome || camp.title || campId;
    console.log(`\nBuscando dados de: ${nome}`);

    // Times
    const { col: timeCol, docs: times } = await fetchSubcollection(TOKEN, campCol, campId,
      ['teams', 'equipes', 'times', 'squads']);
    if (times.length > 0) {
      console.log(`  Times (${timeCol}): ${times.length}`);
      times.forEach(t => { t._campId = campId; t._campNome = nome; });
      dados.times.push(...times);

      // Jogadores
      for (const time of times) {
        const { col: jogCol, docs: jogs } = await fetchSubcollection(TOKEN, campCol,
          `${campId}/${timeCol}/${time._id}`, ['players', 'jogadores', 'athletes', 'members']);
        if (jogs.length > 0) {
          jogs.forEach(j => { j._timeId = time._id; j._campId = campId; });
          dados.jogadores.push(...jogs);
          console.log(`    ${time.name || time.nome}: ${jogs.length} jogadores`);
        }
      }
    }

    // Partidas
    const { col: partCol, docs: partidas } = await fetchSubcollection(TOKEN, campCol, campId,
      ['matches', 'games', 'partidas', 'jogos', 'fixtures']);
    if (partidas.length > 0) {
      console.log(`  Partidas (${partCol}): ${partidas.length}`);
      partidas.forEach(p => { p._campId = campId; });
      dados.partidas.push(...partidas);

      // Lances
      for (const part of partidas) {
        const { col: lanceCol, docs: lances } = await fetchSubcollection(TOKEN, campCol,
          `${campId}/${partCol}/${part._id}`, ['events', 'lances', 'goals', 'incidents', 'actions']);
        if (lances.length > 0) {
          lances.forEach(l => { l._partidaId = part._id; l._campId = campId; });
          dados.lances.push(...lances);
        }
      }
    }
  }

  // 5. Resumo e salva JSON
  console.log('\n\n=== RESUMO FINAL ===');
  console.log(`Campeonatos: ${dados.campeonatos.length}`);
  console.log(`Times: ${dados.times.length}`);
  console.log(`Jogadores: ${dados.jogadores.length}`);
  console.log(`Partidas: ${dados.partidas.length}`);
  console.log(`Lances: ${dados.lances.length}`);

  fs.writeFileSync('copafacil_data.json', JSON.stringify(dados, null, 2), 'utf-8');
  console.log('\nSalvo em copafacil_data.json');

  if (dados.campeonatos.length > 0) {
    await importarParaTVI();
  }
}

async function importarParaTVI() {
  console.log('\n🔥 Importando para TVI News Firestore...');
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
      status: camp.status === 'active' || camp.status === 'em_andamento' ? 'emAndamento' : 'encerrado',
      organizadorId: 'lalomoraes_migrado',
      organizadorNome: camp.organizerName || camp.organizadorNome || 'Lalo Moraes',
      logoUrl: camp.logo || camp.logoUrl || camp.image || null,
      migradoDeCopafacil: true,
      copafacilId: camp._id,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`  ✓ ${nome}`);

    const times = dados.times.filter(t => t._campId === camp._id);
    for (const time of times) {
      const nomeTime = time.name || time.nome || time.teamName || time._id;
      await db.collection('campeonatos').doc(slug).collection('times').doc(time._id).set({
        campeonatoId: slug,
        nome: nomeTime,
        logoUrl: time.logo || time.logoUrl || time.shield || time.escudo || null,
        categoria: time.category || time.categoria || null,
        responsavelNome: time.manager || time.responsavel || time.contact || 'Responsável',
        organizadorId: 'lalomoraes_migrado',
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      const jogadores = dados.jogadores.filter(j => j._timeId === time._id);
      for (const jog of jogadores) {
        await db.collection('campeonatos').doc(slug)
          .collection('times').doc(time._id)
          .collection('jogadores').doc(jog._id).set({
            campeonatoId: slug,
            timeId: time._id,
            nome: jog.name || jog.nome || jog.playerName || 'Jogador',
            apelido: jog.nickname || jog.apelido || null,
            numero: jog.number || jog.numero || jog.shirt || null,
            posicao: jog.position || jog.posicao || null,
            fotoUrl: jog.photo || jog.fotoUrl || jog.photoUrl || null,
          });
      }
    }

    const partidas = dados.partidas.filter(p => p._campId === camp._id);
    for (const part of partidas) {
      await db.collection('campeonatos').doc(slug).collection('partidas').doc(part._id).set({
        campeonatoId: slug,
        timeANome: part.homeTeam || part.teamA || part.home || part.mandante || 'Time A',
        timeBNome: part.awayTeam || part.teamB || part.away || part.visitante || 'Time B',
        placarA: parseInt(part.homeScore ?? part.scoreA ?? part.goalsA ?? 0),
        placarB: parseInt(part.awayScore ?? part.scoreB ?? part.goalsB ?? 0),
        status: 'encerrada',
        dataHora: part.date || part.data || part.scheduledAt || null,
        local: part.local || part.location || part.venue || null,
        faseId: part.phase || part.fase || part.round || part.stage || 'geral',
        copafacilId: part._id,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });

      const lances = dados.lances.filter(l => l._partidaId === part._id);
      for (const lance of lances) {
        await db.collection('campeonatos').doc(slug)
          .collection('partidas').doc(part._id)
          .collection('lances').doc(lance._id).set({
            tipo: lance.type || lance.tipo || lance.eventType || 'ocorrencia',
            jogadorNome: lance.playerName || lance.jogadorNome || lance.player || null,
            timeId: lance.teamId || lance.equipeId || null,
            minuto: parseInt(lance.minute || lance.minuto || 0),
            descricao: lance.description || lance.descricao || lance.note || null,
          });
      }
    }
  }

  console.log('\n✅ Importação concluída! Abra o app TVI e veja os campeonatos.');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
