/**
 * import_classificacao.js
 * Lê a classificação de cada grupo/fase do RTDB da CopáFácil
 * e importa para o Firestore do TVI News.
 * 
 * Estrutura RTDB: /events/{campId}/list_evt/{grupoId}/
 * Estrutura Firestore: campeonatos/{docId}/classificacao/{grupoId}
 */

const https = require('https');
const admin = require('firebase-admin');
const fs = require('fs');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const RTDB = 'copafacil-web.firebaseio.com';

const CAMPS = [
  { rtdb: '-5fqd2',  fs: 'copafacil_5fqd2',  nome: 'Copa TVitapê 2026'       },
  { rtdb: '-jcgq9',  fs: 'copafacil_jcgq9',  nome: 'Copa TVitapê 2025'       },
  { rtdb: '-077g4',  fs: 'copafacil_077g4',  nome: 'Varzeano Itapetininga 2026' },
  { rtdb: '-rmjb0',  fs: 'copafacil_rmjb0',  nome: 'Varzeano Itapetininga 2025' },
];

function postAuth() {
  return new Promise(resolve => {
    const data = JSON.stringify({ email: 'lalomoraes@copafacil.com', password: 'L@lO2@25', returnSecureToken: true });
    const req = https.request({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${API_KEY}`,
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, res => { let d=''; res.on('data',c=>d+=c); res.on('end',()=>{ try{resolve(JSON.parse(d))}catch{resolve({})} }); });
    req.on('error',()=>resolve({})); req.write(data); req.end();
  });
}

function rtdbGet(path, token) {
  return new Promise(resolve => {
    https.get(`https://${RTDB}${path}.json?auth=${token}`, res => {
      let d=''; res.on('data',c=>d+=c);
      res.on('end',()=>{ try{resolve({ok:res.statusCode===200, data:JSON.parse(d)})}catch{resolve({ok:false,data:null})} });
    }).on('error',()=>resolve({ok:false,data:null}));
  });
}

function parseTeamStanding(timeData, teamId) {
  if (!timeData || typeof timeData !== 'object') return null;
  
  // Campos possíveis no RTDB da CopáFácil
  return {
    teamId,
    nome: timeData.name || timeData.nome || timeData.n || timeData.short_name || timeData.title || `Time ${teamId.substring(0,8)}`,
    logoUrl: timeData.logo || timeData.image || timeData.photo || timeData.shield || null,
    pontos: parseInt(timeData.pts || timeData.points || timeData.p || 0),
    jogos: parseInt(timeData.gp || timeData.games || timeData.j || timeData.played || 0),
    vitorias: parseInt(timeData.gw || timeData.wins || timeData.v || timeData.w || 0),
    empates: parseInt(timeData.gd || timeData.draws || timeData.e || timeData.d || 0),
    derrotas: parseInt(timeData.gl || timeData.losses || timeData.de || timeData.l || 0),
    golsPro: parseInt(timeData.fg || timeData.goalsFor || timeData.gf || timeData.sf || 0),
    golsContra: parseInt(timeData.ag || timeData.goalsAgainst || timeData.gc || timeData.sa || 0),
    saldoGols: parseInt(timeData.sg || timeData.goalDifference || timeData.gd2 || 0),
    posicao: parseInt(timeData.pos || timeData.position || timeData.rank || 0),
  };
}

async function main() {
  console.log('=== IMPORTANDO CLASSIFICAÇÃO + NOMES DOS TIMES ===\n');
  
  const auth = await postAuth();
  if (!auth.idToken) { console.error('Auth falhou'); return; }
  const TOKEN = auth.idToken;
  console.log('Auth OK\n');

  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  const allTeamNames = {}; // Cache global de nomes: teamId → nome

  for (const camp of CAMPS) {
    console.log(`\n=== ${camp.nome} ===`);
    const campRef = db.collection('campeonatos').doc(camp.fs);
    
    // 1. Lê todos os grupos do list_evt
    const listEvtR = await rtdbGet(`/events/${camp.rtdb}/list_evt`, TOKEN);
    if (!listEvtR.ok || !listEvtR.data) {
      console.log('  Sem acesso ao list_evt');
      continue;
    }
    
    const grupos = Object.entries(listEvtR.data);
    console.log(`  ${grupos.length} grupos/fases encontrados`);

    let totalTimesImportados = 0;
    let totalClassificacaoSalva = 0;

    for (const [grupoId, grupoData] of grupos) {
      // 2. Lê dados completos do grupo diretamente
      const grupoFullR = await rtdbGet(`/events/${camp.rtdb}/list_evt/${grupoId}`, TOKEN);
      if (!grupoFullR.ok || !grupoFullR.data) continue;
      
      const grupoFull = grupoFullR.data;
      const chaves = Object.keys(grupoFull);
      
      // Procura times no grupo em varios sub-paths
      let timesNoGrupo = {};
      
      // Tenta sub-paths comuns
      for (const subPath of ['t', 'teams', 'equipes', 'class', 'standings', 'ranking']) {
        if (grupoFull[subPath] && typeof grupoFull[subPath] === 'object') {
          timesNoGrupo = grupoFull[subPath];
          console.log(`  Grupo ${grupoId}: ${Object.keys(timesNoGrupo).length} times em /${subPath}`);
          break;
        }
      }
      
      // Se não achou sub-path, tenta ler /t diretamente
      if (Object.keys(timesNoGrupo).length === 0) {
        const tR = await rtdbGet(`/events/${camp.rtdb}/list_evt/${grupoId}/t`, TOKEN);
        if (tR.ok && tR.data && typeof tR.data === 'object') {
          timesNoGrupo = tR.data;
          console.log(`  Grupo ${grupoId}/t: ${Object.keys(timesNoGrupo).length} times`);
        }
      }

      if (Object.keys(timesNoGrupo).length === 0) {
        // Mostra o que tem no grupo para debug
        if (chaves.length > 1) {
          console.log(`  Grupo ${grupoId}: chaves=${chaves.join(',')}`);
        }
        continue;
      }
      
      // 3. Processa times deste grupo
      const classificacao = [];
      
      for (const [teamId, teamData] of Object.entries(timesNoGrupo)) {
        const standing = parseTeamStanding(teamData, teamId);
        if (!standing) continue;
        
        // Atualiza cache de nomes
        if (standing.nome && !standing.nome.startsWith('Time ')) {
          allTeamNames[teamId] = standing.nome;
        }
        
        classificacao.push(standing);
        totalTimesImportados++;
        
        // Salva time na coleção times
        await campRef.collection('times').doc(teamId.replace(/[^a-zA-Z0-9_-]/g, '_')).set({
          campeonatoId: camp.fs,
          nome: standing.nome,
          logoUrl: standing.logoUrl,
          grupoId,
          copafacilTeamId: teamId,
          organizadorId: 'lalomoraes_migrado',
          criadoEm: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
      }
      
      // 4. Salva classificação no Firestore
      if (classificacao.length > 0) {
        // Ordena por pontos → saldo de gols → gols pro
        classificacao.sort((a, b) => {
          if (b.pontos !== a.pontos) return b.pontos - a.pontos;
          if (b.saldoGols !== a.saldoGols) return b.saldoGols - a.saldoGols;
          return b.golsPro - a.golsPro;
        });
        
        // Atribui posições
        classificacao.forEach((t, i) => { t.posicao = i + 1; });
        
        const grupoNome = grupoId.split('@')[1] || grupoId;
        await campRef.collection('classificacao').doc(grupoId).set({
          grupoId,
          grupoNome,
          campeonatoId: camp.fs,
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          times: classificacao,
        });
        
        totalClassificacaoSalva++;
        console.log(`  ✓ Classificação ${grupoId}: ${classificacao.length} times`);
        classificacao.forEach(t => console.log(`    ${t.posicao}. ${t.nome} — ${t.pontos}pts (${t.jogos}J ${t.vitorias}V ${t.empates}E ${t.derrotas}D ${t.golsPro}:${t.golsContra})`));
      }
    }
    
    // 5. Atualiza nomes das partidas com os nomes reais dos times
    if (Object.keys(allTeamNames).length > 0) {
      console.log(`\n  Atualizando nomes nas partidas...`);
      const partidasSnap = await campRef.collection('partidas').get();
      let atualizadas = 0;
      
      // Atualiza em batches de 400
      const BATCH_SIZE = 400;
      const docs = partidasSnap.docs;
      
      for (let i = 0; i < docs.length; i += BATCH_SIZE) {
        const batch = db.batch();
        const chunk = docs.slice(i, i + BATCH_SIZE);
        
        for (const doc of chunk) {
          const data = doc.data();
          const updates = {};
          
          if (data.timeAId && allTeamNames[data.timeAId]) {
            updates.timeANome = allTeamNames[data.timeAId];
          }
          if (data.timeBId && allTeamNames[data.timeBId]) {
            updates.timeBNome = allTeamNames[data.timeBId];
          }
          
          if (Object.keys(updates).length > 0) {
            batch.update(doc.ref, updates);
            atualizadas++;
          }
        }
        await batch.commit();
      }
      console.log(`  ✓ ${atualizadas} partidas atualizadas com nomes reais`);
    }
    
    console.log(`\n  Resumo ${camp.nome}:`);
    console.log(`    Times importados: ${totalTimesImportados}`);
    console.log(`    Grupos/Fases com classificação: ${totalClassificacaoSalva}`);
  }

  // Salva nomes para inspeção
  fs.writeFileSync('team_names_cache.json', JSON.stringify(allTeamNames, null, 2));
  console.log(`\n\nTotal times com nome: ${Object.keys(allTeamNames).length}`);
  console.log('✅ CLASSIFICAÇÃO E TIMES IMPORTADOS!');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
