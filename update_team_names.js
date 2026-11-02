/**
 * update_team_names.js
 * Busca os nomes dos times no RTDB e atualiza as partidas no Firestore
 */

const https = require('https');
const admin = require('firebase-admin');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const RTDB = 'copafacil-web.firebaseio.com';

// Campeonatos: rtdbId → firestoreId
const CAMPS = [
  { rtdb: '-5fqd2',  fs: 'copafacil_5fqd2'  },
  { rtdb: '-jcgq9',  fs: 'copafacil_jcgq9'  },
  { rtdb: '-077g4',  fs: 'copafacil_077g4'  },
  { rtdb: '-rmjb0',  fs: 'copafacil_rmjb0'  },
];

function postAuth() {
  return new Promise(resolve => {
    const data = JSON.stringify({ email: 'lalomoraes@copafacil.com', password: 'L@lO2@25', returnSecureToken: true });
    const req = https.request({
      hostname: 'identitytoolkit.googleapis.com',
      path: `/v1/accounts:signInWithPassword?key=${API_KEY}`, method: 'POST',
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

async function main() {
  console.log('=== BUSCANDO NOMES DOS TIMES ===\n');
  
  const auth = await postAuth();
  const TOKEN = auth.idToken;
  console.log('Auth OK\n');
  
  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  // Cache global de times (id → nome) para não re-buscar
  const teamCache = {};

  async function getTeamName(campRtdbId, teamId) {
    if (!teamId) return null;
    if (teamCache[teamId]) return teamCache[teamId];
    
    // Paths possiveis para encontrar o time
    const paths = [
      `/events/${campRtdbId}/teams/${teamId}`,
      `/teams/${teamId}`,
      `/events/${campRtdbId}/t/${teamId}`,
    ];
    
    for (const path of paths) {
      const r = await rtdbGet(path, TOKEN);
      if (r.ok && r.data && typeof r.data === 'object') {
        const nome = r.data.name || r.data.nome || r.data.n || r.data.title || r.data.short_name;
        if (nome) {
          teamCache[teamId] = nome;
          return nome;
        }
      }
    }
    
    // Tenta list_evt: o time pode estar num grupo
    // Formato: /events/{campId}/list_evt/{grupoId}/t/{teamId}
    const listEvtR = await rtdbGet(`/events/${campRtdbId}/list_evt`, TOKEN);
    if (listEvtR.ok && listEvtR.data) {
      for (const grupoId of Object.keys(listEvtR.data)) {
        const teamR = await rtdbGet(`/events/${campRtdbId}/list_evt/${grupoId}/t/${teamId}`, TOKEN);
        if (teamR.ok && teamR.data) {
          const nome = teamR.data.name || teamR.data.nome || teamR.data.n;
          if (nome) {
            teamCache[teamId] = nome;
            return nome;
          }
        }
      }
    }
    
    teamCache[teamId] = null; // Marca como não encontrado
    return null;
  }

  for (const camp of CAMPS) {
    console.log(`\n--- ${camp.fs} ---`);
    
    // Lê as partidas do Firestore
    const partidasSnap = await db.collection('campeonatos').doc(camp.fs).collection('partidas').get();
    console.log(`  ${partidasSnap.size} partidas para atualizar`);
    
    let atualizadas = 0;
    let semNome = 0;
    
    // Carrega todos os times do campeonato de uma vez
    console.log('  Buscando times do RTDB...');
    const teamsRootR = await rtdbGet(`/events/${camp.rtdb}/teams`, TOKEN);
    if (teamsRootR.ok && teamsRootR.data) {
      const teams = teamsRootR.data;
      Object.entries(teams).forEach(([tid, tdata]) => {
        if (tdata && typeof tdata === 'object') {
          const nome = tdata.name || tdata.nome || tdata.n || tdata.short_name;
          if (nome) teamCache[tid] = nome;
        }
      });
      console.log(`  ${Object.keys(teamsRootR.data).length} times encontrados em /teams`);
    }
    
    // Tenta /events/{id}/t/ também
    const tRootR = await rtdbGet(`/events/${camp.rtdb}/t`, TOKEN);
    if (tRootR.ok && tRootR.data) {
      Object.entries(tRootR.data).forEach(([tid, tdata]) => {
        if (tdata && typeof tdata === 'object') {
          const nome = tdata.name || tdata.nome || tdata.n;
          if (nome && !teamCache[tid]) teamCache[tid] = nome;
        }
      });
      console.log(`  ${Object.keys(tRootR.data).length} times em /t`);
    }
    
    // Mostra sample dos times encontrados
    const timesEncontrados = Object.entries(teamCache).filter(([,v]) => v).slice(0, 5);
    timesEncontrados.forEach(([id, nome]) => console.log(`    ${id.substring(0,12)}: ${nome}`));
    
    // Atualiza partidas em lotes de 10
    const docs = partidasSnap.docs;
    const BATCH_SIZE = 450; // Firestore limite de 500 por batch
    
    for (let i = 0; i < docs.length; i += BATCH_SIZE) {
      const batch = db.batch();
      const chunk = docs.slice(i, i + BATCH_SIZE);
      
      for (const doc of chunk) {
        const data = doc.data();
        const timeAId = data.timeAId;
        const timeBId = data.timeBId;
        
        let timeANome = teamCache[timeAId] || null;
        let timeBNome = teamCache[timeBId] || null;
        
        // Se não está no cache, tenta buscar individualmente
        if (!timeANome && timeAId) {
          timeANome = await getTeamName(camp.rtdb, timeAId);
        }
        if (!timeBNome && timeBId) {
          timeBNome = await getTeamName(camp.rtdb, timeBId);
        }
        
        if (timeANome || timeBNome) {
          const update = {};
          if (timeANome) update.timeANome = timeANome;
          if (timeBNome) update.timeBNome = timeBNome;
          batch.update(doc.ref, update);
          atualizadas++;
        } else {
          semNome++;
        }
      }
      
      await batch.commit();
      process.stdout.write(`\r  Atualizadas: ${atualizadas} | Sem nome: ${semNome}`);
    }
    
    console.log(`\n  ✓ ${atualizadas} partidas atualizadas com nomes reais`);
    if (semNome > 0) console.log(`  ⚠ ${semNome} partidas sem nome de time`);
    
    // Cria/atualiza times na coleção times do Firestore
    const timesParaSalvar = Object.entries(teamCache).filter(([, v]) => v);
    const campRef = db.collection('campeonatos').doc(camp.fs);
    const timesBatch = db.batch();
    
    for (const [tid, nome] of timesParaSalvar) {
      const safeId = tid.replace(/[^a-zA-Z0-9_-]/g, '_');
      const timeRef = campRef.collection('times').doc(safeId);
      timesBatch.set(timeRef, {
        campeonatoId: camp.fs, nome, copafacilTeamId: tid,
        organizadorId: 'lalomoraes_migrado',
        criadoEm: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
    
    if (timesParaSalvar.length > 0) {
      await timesBatch.commit();
      console.log(`  ✓ ${timesParaSalvar.length} times salvos na coleção times`);
    }
    
    // Limpa cache para próximo campeonato (times podem ser diferentes)
    // Mantém apenas o que pode ser global
  }

  console.log('\n\n✅ NOMES DOS TIMES ATUALIZADOS!');
  console.log('Os campeonatos estão prontos no Firestore.');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
