/**
 * import_all_camps.js
 * Importa TODOS os 4 campeonatos seguindo a cadeia previous/next no RTDB
 */

const https = require('https');
const admin = require('firebase-admin');
const fs = require('fs');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const EMAIL = 'lalomoraes@copafacil.com';
const SENHA = 'L@lO2@25';
const RTDB = 'copafacil-web.firebaseio.com';

function postAuth() {
  return new Promise(resolve => {
    const data = JSON.stringify({ email: EMAIL, password: SENHA, returnSecureToken: true });
    const req = https.request({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${API_KEY}`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, res => { let d = ''; res.on('data', c => d += c); res.on('end', () => { try { resolve(JSON.parse(d)); } catch { resolve({}); } }); });
    req.on('error', () => resolve({}));
    req.write(data); req.end();
  });
}

function rtdbGet(path, token) {
  return new Promise(resolve => {
    https.get(`https://${RTDB}${path}.json?auth=${token}`, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ ok: res.statusCode === 200, data: JSON.parse(d) }); } catch { resolve({ ok: false, data: null }); } });
    }).on('error', () => resolve({ ok: false, data: null }));
  });
}

async function main() {
  console.log('=== IMPORTACAO TODOS OS CAMPEONATOS ===\n');

  const auth = await postAuth();
  if (!auth.idToken) { console.error('Auth falhou'); return; }
  const TOKEN = auth.idToken;
  console.log('Auth OK. UID:', auth.localId);

  // Segue a cadeia de campeonatos pelo campo "previous"
  const campIds = new Set(['-5fqd2']);
  const queue = ['-5fqd2'];
  const allCampData = {};

  while (queue.length > 0) {
    const campId = queue.shift();
    console.log(`\nLendo campeonato ${campId}...`);
    
    // Lê info do campeonato
    const infoR = await rtdbGet(`/events/${campId}/info`, TOKEN);
    if (!infoR.ok || !infoR.data) { console.log('  Sem acesso'); continue; }
    
    const info = infoR.data;
    const nome = info.info?.title?.trim() || info.title?.trim() || `Campeonato ${campId}`;
    console.log(`  Nome: ${nome}`);
    console.log(`  Admin: ${info.admin}`);
    console.log(`  Previous: ${info.previous || 'nenhum'}`);
    console.log(`  Site: ${info.site || '-'}`);
    
    // Segue previous/next
    if (info.previous && !campIds.has(info.previous)) {
      campIds.add(info.previous);
      queue.push(info.previous);
      console.log(`  → Adiciona previous: ${info.previous}`);
    }
    if (info.next && !campIds.has(info.next)) {
      campIds.add(info.next);
      queue.push(info.next);
    }

    // Lê partidas
    const matchsR = await rtdbGet(`/events/${campId}/matchs`, TOKEN);
    const matchs = matchsR.ok ? (matchsR.data || {}) : {};
    console.log(`  Partidas: ${Object.keys(matchs).length}`);

    // Lê grupos/times
    const listEvtR = await rtdbGet(`/events/${campId}/list_evt`, TOKEN);
    const listEvt = listEvtR.ok ? (listEvtR.data || {}) : {};
    const grupos = Object.keys(listEvt);
    console.log(`  Grupos: ${grupos.length} → ${grupos.join(', ')}`);

    // Para cada grupo, tenta ler sub-dados (teams, standings)
    const teamsData = {};
    for (const grupoId of grupos.slice(0, 10)) {
      // Tenta varios sub-paths para encontrar os times
      for (const sub of ['t', 'teams', 'equipes', 'standings', 'class']) {
        const r = await rtdbGet(`/events/${campId}/list_evt/${grupoId}/${sub}`, TOKEN);
        if (r.ok && r.data && typeof r.data === 'object') {
          console.log(`    ${grupoId}/${sub}: ${Object.keys(r.data).length} items`);
          const sample = Object.entries(r.data)[0];
          if (sample) console.log(`    Amostra: ${sample[0]} → ${JSON.stringify(sample[1]).substring(0, 100)}`);
          Object.assign(teamsData, r.data);
          break;
        }
      }
    }

    // Lê nomes dos times via IDs das partidas
    const teamIds = new Set();
    for (const match of Object.values(matchs)) {
      if (match.team1) teamIds.add(match.team1);
      if (match.team2) teamIds.add(match.team2);
    }
    console.log(`  Time IDs únicos: ${teamIds.size}`);

    // Lê dados de cada time
    const times = {};
    const teamIdArr = [...teamIds].slice(0, 30);
    for (const teamId of teamIdArr) {
      // Times podem estar em /teams/{id} ou /events/{campId}/teams/{id}
      for (const timePath of [
        `/events/${campId}/teams/${teamId}`,
        `/teams/${teamId}`,
        `/events/${campId}/list_evt/${campId}@${teamId.split('@')[1] || teamId}/t/${teamId}`,
      ]) {
        const r = await rtdbGet(timePath, TOKEN);
        if (r.ok && r.data && r.data !== 'null') {
          times[teamId] = r.data;
          console.log(`    Time ${teamId}: ${r.data.name || r.data.nome || JSON.stringify(r.data).substring(0, 80)}`);
          break;
        }
      }
    }

    allCampData[campId] = { id: campId, nome, info, matchs, listEvt, teamsData, times };
  }

  // Salva JSON para inspecao
  fs.writeFileSync('copafacil_all_camps.json', JSON.stringify(allCampData, null, 2), 'utf-8');
  console.log(`\nTotal campeonatos: ${Object.keys(allCampData).length}`);
  console.log('Salvo em copafacil_all_camps.json');

  // Importa para TVI Firestore
  console.log('\n=== IMPORTANDO PARA FIRESTORE ===');
  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  for (const [campId, camp] of Object.entries(allCampData)) {
    const docId = `copafacil_${campId.replace(/^-/, '')}`;
    const campRef = db.collection('campeonatos').doc(docId);

    // Upsert campeonato
    await campRef.set({
      nome: camp.nome,
      descricao: camp.info.info?.sub_title || '',
      esporte: 'futebol',
      status: 'encerrado',
      organizadorId: 'lalomoraes_migrado',
      organizadorNome: 'MM Eventos',
      logoUrl: camp.info.url || null,
      siteUrl: camp.info.site || null,
      migradoDeCopafacil: true,
      copafacilId: campId,
      criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`\n✓ ${camp.nome} (${docId})`);

    // Importa times conhecidos
    let timesCount = 0;
    for (const [tId, tData] of Object.entries(camp.times)) {
      if (!tData || typeof tData !== 'object') continue;
      const nomeTime = tData.name || tData.nome || tData.n || `Time ${tId.substring(0, 8)}`;
      await campRef.collection('times').doc(tId.replace(/[^a-zA-Z0-9_-]/g, '_')).set({
        campeonatoId: docId,
        nome: nomeTime,
        logoUrl: tData.logo || tData.image || tData.photo || null,
        copafacilTeamId: tId,
        organizadorId: 'lalomoraes_migrado',
      });
      timesCount++;
    }
    if (timesCount > 0) console.log(`  ${timesCount} times`);

    // Importa partidas
    let partidasCount = 0;
    for (const [matchId, match] of Object.entries(camp.matchs)) {
      if (!match || typeof match !== 'object') continue;
      const placarA = match.dt?.qt_g1 ?? match.score1 ?? match.goals1 ?? 0;
      const placarB = match.dt?.qt_g2 ?? match.score2 ?? match.goals2 ?? 0;
      const timeA = camp.times[match.team1];
      const timeB = camp.times[match.team2];

      await campRef.collection('partidas').doc(matchId).set({
        campeonatoId: docId,
        timeANome: timeA?.name || timeA?.nome || timeA?.n || match.team1?.substring(0, 8) || 'Time A',
        timeBNome: timeB?.name || timeB?.nome || timeB?.n || match.team2?.substring(0, 8) || 'Time B',
        timeAId: match.team1 || null,
        timeBId: match.team2 || null,
        placarA: parseInt(placarA) || 0,
        placarB: parseInt(placarB) || 0,
        status: match.st === 3 ? 'encerrada' : match.st === 2 ? 'emAndamento' : 'agendada',
        dataTimestamp: match.d_i || null,
        faseId: match.evt || 'geral',
        local: match.l || null,
        copafacilMatchId: matchId,
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      });
      partidasCount++;
    }
    if (partidasCount > 0) console.log(`  ${partidasCount} partidas`);
  }

  console.log('\n✅ IMPORTACAO CONCLUIDA!');
  console.log('Abra o app TVI → aba Campeonatos para ver os dados.');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
