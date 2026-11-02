/**
 * import_rtdb_full.js
 * Le TODOS os dados dos campeonatos do Firebase RTDB da CopáFácil
 * e importa para o TVI News Firestore.
 * 
 * Banco descoberto: copafacil-web.firebaseio.com
 * Caminho: /events/{id}
 * Copa TVitapê 2026: -5fqd2
 */

const https = require('https');
const admin = require('firebase-admin');
const fs = require('fs');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const EMAIL = 'lalomoraes@copafacil.com';
const SENHA = 'L@lO2@25';
const RTDB = 'copafacil-web.firebaseio.com';

function postAuth(body) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${API_KEY}`,
      method: 'POST',
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

function rtdb(path, token) {
  return new Promise(resolve => {
    const url = `https://${RTDB}${path}.json?auth=${token}`;
    https.get(url, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, data: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, data: null }); }
      });
    }).on('error', () => resolve({ status: 0, data: null }));
  });
}

async function main() {
  console.log('=== IMPORTACAO COMPLETA COPAFACIL → TVI NEWS ===\n');

  // 1. Auth
  const auth = await postAuth({ email: EMAIL, password: SENHA, returnSecureToken: true });
  if (!auth.idToken) { console.error('Erro auth'); return; }
  const TOKEN = auth.idToken;
  const UID = auth.localId;
  console.log(`Auth OK. UID: ${UID}\n`);

  // 2. Busca TODOS os campeonatos do usuario
  console.log('Buscando campeonatos do usuario...');
  
  // Tenta listar /events/ e filtrar por proprietario
  // Tenta tambem /users/{uid} para pegar lista de campeonatos
  let campIds = ['-5fqd2']; // Já sabemos esse
  
  // Busca mais IDs via /users/{uid}
  for (const userPath of [`/users/${UID}`, `/organizers/${UID}`, `/user/${UID}`]) {
    const r = await rtdb(userPath, TOKEN);
    if (r.status === 200 && r.data) {
      console.log(`${userPath}: ${JSON.stringify(r.data).substring(0, 300)}`);
      // Procura lista de eventos/campeonatos
      if (r.data.events) {
        const ids = typeof r.data.events === 'object' ? Object.keys(r.data.events) : [];
        campIds = [...new Set([...campIds, ...ids])];
        console.log(`  → Campeonatos do usuario: ${ids.join(', ')}`);
      }
    }
  }
  
  // Busca lista de eventos do organizador
  const adminEventsPath = `/organizer_events/${UID}`;
  const adminR = await rtdb(adminEventsPath, TOKEN);
  if (adminR.status === 200 && adminR.data) {
    const ids = Object.keys(adminR.data);
    campIds = [...new Set([...campIds, ...ids])];
    console.log(`organizer_events: ${ids.join(', ')}`);
  }

  // Tenta /events ordenado por uid
  const eventsAllR = await rtdb('/events', TOKEN);
  if (eventsAllR.status === 200 && eventsAllR.data && typeof eventsAllR.data === 'object') {
    // Filtra eventos que pertencem ao usuario
    const doUser = Object.entries(eventsAllR.data)
      .filter(([k, v]) => {
        if (!v || typeof v !== 'object') return false;
        const info = v.info || {};
        return info.uid === UID || info.owner === UID || info.userId === UID ||
               info.organizerId === UID || v.uid === UID;
      })
      .map(([k]) => k);
    
    if (doUser.length > 0) {
      console.log(`Eventos do usuario encontrados: ${doUser.join(', ')}`);
      campIds = [...new Set([...campIds, ...doUser])];
    } else {
      // Mostra primeiros eventos para debug
      const allIds = Object.keys(eventsAllR.data);
      console.log(`Total eventos no RTDB: ${allIds.length}`);
      if (allIds.length <= 50) console.log('IDs:', allIds.join(', '));
    }
  }

  console.log(`\nCampeonatos para processar: ${campIds.join(', ')}\n`);

  // 3. Lê dados completos de cada campeonato
  const campeonatos = [];
  
  for (const campId of campIds) {
    console.log(`\n--- Lendo campeonato ${campId} ---`);
    const campR = await rtdb(`/events/${campId}`, TOKEN);
    
    if (campR.status !== 200 || !campR.data) {
      console.log(`  Erro: ${campR.status}`);
      continue;
    }
    
    const camp = campR.data;
    const info = camp.info || {};
    const nome = info.name || info.nome || info.title || `Campeonato ${campId}`;
    
    console.log(`  Nome: ${nome}`);
    console.log(`  Chaves: ${Object.keys(camp).join(', ')}`);
    
    // Lê sub-paths importantes
    const subPaths = ['info', 'matchs', 'list_evt', 'places', 'inf_up', 'more_info'];
    for (const sub of subPaths) {
      if (!camp[sub]) {
        const subR = await rtdb(`/events/${campId}/${sub}`, TOKEN);
        if (subR.status === 200 && subR.data) {
          camp[sub] = subR.data;
        }
      }
    }

    // Extrai dados estruturados
    const matchs = camp.matchs || {};
    const listEvt = camp.list_evt || {};
    const moreInfo = camp.more_info || {};
    
    console.log(`  Partidas: ${Object.keys(matchs).length}`);
    console.log(`  Times/Grupos: ${Object.keys(listEvt).length}`);
    
    campeonatos.push({ id: campId, nome, info, matchs, listEvt, moreInfo, raw: camp });
    
    // Mostra algumas partidas para debug
    const matchKeys = Object.keys(matchs).slice(0, 3);
    if (matchKeys.length > 0) {
      console.log('  Exemplo partida:', JSON.stringify(matchs[matchKeys[0]]).substring(0, 200));
    }
  }

  // 4. Salva JSON completo
  fs.writeFileSync('copafacil_rtdb_full.json', JSON.stringify({ campeonatos }, null, 2), 'utf-8');
  console.log('\nDados salvos em copafacil_rtdb_full.json');

  // 5. Importa para TVI Firestore
  console.log('\n=== IMPORTANDO PARA TVI FIRESTORE ===');
  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();
  const batch = db.batch();

  for (const camp of campeonatos) {
    const { id, nome, info, matchs, listEvt } = camp;
    const docId = `copafacil_${id.replace(/^-/, '')}`;
    
    // Campeonato principal
    const campRef = db.collection('campeonatos').doc(docId);
    batch.set(campRef, {
      nome,
      descricao: info.description || info.descricao || info.subtitle || '',
      esporte: info.sport || info.esporte || info.modality || 'futebol',
      status: 'encerrado',
      organizadorId: 'lalomoraes_migrado',
      organizadorNome: info.organizer || info.organizerName || 'MM Eventos',
      logoUrl: info.logo || info.image || info.photo || null,
      local: info.city || info.local || info.location || null,
      dataInicio: info.start_date || info.startDate || info.date_start || null,
      dataFim: info.end_date || info.endDate || info.date_end || null,
      migradoDeCopafacil: true,
      copafacilId: id,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`\n✓ Campeonato: ${nome} → ${docId}`);

    // Times (list_evt)
    let timesCount = 0;
    for (const [grupoId, grupo] of Object.entries(listEvt)) {
      if (!grupo || typeof grupo !== 'object') continue;
      
      // list_evt pode ter grupos ou times direto
      const times = grupo.teams || grupo.times || grupo.equipes || grupo;
      if (typeof times !== 'object') continue;
      
      for (const [timeId, time] of Object.entries(times)) {
        if (!time || typeof time !== 'object') continue;
        const nomeTime = time.name || time.nome || time.teamName || `Time ${timeId}`;
        const timeRef = campRef.collection('times').doc(timeId);
        batch.set(timeRef, {
          campeonatoId: docId,
          nome: nomeTime,
          grupoId: grupoId,
          logoUrl: time.logo || time.image || null,
          pontos: time.pts || time.points || time.pontos || 0,
          jogos: time.gp || time.games || time.jogos || 0,
          vitorias: time.gw || time.wins || time.vitorias || 0,
          empates: time.gd || time.draws || time.empates || 0,
          derrotas: time.gl || time.losses || time.derrotas || 0,
          golsPro: time.fg || time.goalsFor || time.golsPro || 0,
          golsContra: time.ag || time.goalsAgainst || time.golsContra || 0,
          organizadorId: 'lalomoraes_migrado',
        });
        timesCount++;
      }
    }
    if (timesCount > 0) console.log(`  ${timesCount} times`);

    // Partidas (matchs)
    let partidasCount = 0;
    for (const [matchId, match] of Object.entries(matchs)) {
      if (!match || typeof match !== 'object') continue;
      
      const timeANome = match.team_home || match.home || match.teamA || match.homeTeam || match.t1 || 'Time A';
      const timeBNome = match.team_away || match.away || match.teamB || match.awayTeam || match.t2 || 'Time B';
      const placarA = parseInt(match.score_home ?? match.goalsHome ?? match.scoreA ?? match.r1 ?? match.gols_home ?? 0);
      const placarB = parseInt(match.score_away ?? match.goalsAway ?? match.scoreB ?? match.r2 ?? match.gols_away ?? 0);
      
      const partidaRef = campRef.collection('partidas').doc(matchId);
      batch.set(partidaRef, {
        campeonatoId: docId,
        timeANome,
        timeBNome,
        timeAId: match.home_id || match.teamAId || match.id_home || null,
        timeBId: match.away_id || match.teamBId || match.id_away || null,
        placarA: isNaN(placarA) ? 0 : placarA,
        placarB: isNaN(placarB) ? 0 : placarB,
        status: 'encerrada',
        dataHora: match.date || match.data || match.date_time || match.datetime || null,
        local: match.location || match.local || match.place || null,
        rodada: match.round || match.rodada || match.fase || match.stage || null,
        faseId: match.phase || match.fase || match.group || 'geral',
        copafacilMatchId: matchId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      // Lances/eventos da partida
      const lances = match.events || match.lances || match.goals || match.goals_list || [];
      if (Array.isArray(lances)) {
        lances.forEach((lance, i) => {
          const lanceRef = partidaRef.collection('lances').doc(`lance_${i}`);
          batch.set(lanceRef, {
            tipo: lance.type || lance.tipo || 'gol',
            jogadorNome: lance.player || lance.jogador || lance.playerName || null,
            timeNome: lance.team || lance.time || null,
            minuto: parseInt(lance.minute || lance.minuto || 0),
            descricao: lance.description || lance.descricao || null,
          });
        });
      }
      partidasCount++;
    }
    if (partidasCount > 0) console.log(`  ${partidasCount} partidas`);
  }

  // Commit batch
  try {
    await batch.commit();
    console.log('\n✅ IMPORTAÇÃO CONCLUÍDA COM SUCESSO!');
    console.log('Abra o app TVI e veja os campeonatos na aba Campeonatos.');
  } catch (e) {
    // Batch muito grande? Tenta um por um
    console.log('Batch falhou, tentando um por um...');
    // (simplificado - apenas campeonatos neste caso)
    for (const camp of campeonatos) {
      const docId = `copafacil_${camp.id.replace(/^-/, '')}`;
      await db.collection('campeonatos').doc(docId).set({
        nome: camp.nome, esporte: 'futebol', status: 'encerrado',
        organizadorId: 'lalomoraes_migrado', migradoDeCopafacil: true,
        copafacilId: camp.id, criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
    console.log('✅ Campeonatos importados (sem sub-dados)');
  }

  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message, e.stack); process.exit(1); });
