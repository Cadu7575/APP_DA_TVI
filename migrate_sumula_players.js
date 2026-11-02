const { initializeApp: initClientApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const admin = require('firebase-admin');
const https = require('https');

// TVI News Admin
const sa = require('./tvi-news-service-account.json');
admin.initializeApp({
  credential: admin.credential.cert(sa)
});
const tviDb = admin.firestore();

// Copa Fácil Client
const COPAFACIL_CONFIG = {
  apiKey: "AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0",
  authDomain: "copafacil-web.firebaseapp.com",
  databaseURL: "https://copafacil-web.firebaseio.com",
  projectId: "copafacil-web"
};
const cfApp = initClientApp(COPAFACIL_CONFIG);
const cfAuth = getAuth(cfApp);

const TOURNAMENTS = [
  { campId: 'copafacil_rmjb0', categories: ['-rmjb0@iffu', '-rmjb0@k6f8'] },
  { campId: 'copafacil_jcgq9', categories: ['-jcgq9@9v8k', '-jcgq9@ztuy', '-jcgq9@arqr', '-jcgq9@gytm', '-jcgq9@qckh', '-jcgq9@284z', '-jcgq9@5mng', '-jcgq9@v3dl', '-jcgq9@5mv4'] },
  { campId: 'copafacil_077g4', categories: ['-077g4@86vf', '-077g4@958ly', '-077g4@vqo6p'] },
  { campId: 'copafacil_5fqd2', categories: ['-5fqd2@1y6x', '-5fqd2@v9gyy', '-5fqd2@zda6m', '-5fqd2@88imd', '-5fqd2@ah1bq', '-5fqd2@fy1s7', '-5fqd2@t0qyn', '-5fqd2@1rf6i', '-5fqd2@8ohik'] }
];

function fetchJson(url) {
  return new Promise((resolve, reject) => {
    https.get(url, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try {
          if (!d || d === 'null') resolve(null);
          else resolve(JSON.parse(d));
        } catch (e) {
          resolve(null);
        }
      });
    }).on('error', reject);
  });
}

async function run() {
  console.log('Autenticando no Copa Fácil...');
  const cred = await signInWithEmailAndPassword(cfAuth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const token = await cred.user.getIdToken();
  console.log('✅ Autenticado com sucesso!');

  let totalPlayersImported = 0;
  let totalLancesImported = 0;

  for (const tourney of TOURNAMENTS) {
    console.log(`\n======================================================`);
    console.log(`Processando Campeonato: ${tourney.campId}`);
    console.log(`======================================================`);

    // Dicionário global de jogadores desta competição: playerId -> playerData
    const playersCache = {};

    // 1. IMPORTAR JOGADORES DE CADA CATEGORIA
    for (const cat of tourney.categories) {
      console.log(`  Buscando jogadores da categoria ${cat}...`);
      const playersObj = await fetchJson(`https://copafacil-web.firebaseio.com/events/${cat}/player.json?auth=${token}`);
      if (!playersObj) continue;

      let pCount = 0;
      for (const [plId, pData] of Object.entries(playersObj)) {
        playersCache[plId] = {
          id: plId,
          nome: pData.name || pData.nickname || 'Jogador',
          apelido: pData.nickname || null,
          fotoUrl: pData.url || null,
          posicao: pData.p || null,
          teamId: pData.team || 'sem_time',
          numero: pData.msg || pData.num || null
        };

        // Salvar jogador no Firestore do time correspondente
        if (pData.team) {
          try {
            await tviDb.collection('campeonatos').doc(tourney.campId)
              .collection('times').doc(pData.team)
              .collection('jogadores').doc(plId)
              .set({
                id: plId,
                nome: pData.name || pData.nickname || 'Jogador',
                apelido: pData.nickname || null,
                fotoUrl: pData.url || null,
                posicao: pData.p || null,
                timeId: pData.team,
                campeonatoId: tourney.campId,
                criadoEm: admin.firestore.FieldValue.serverTimestamp()
              }, { merge: true });
            pCount++;
            totalPlayersImported++;
          } catch (e) {
            // Ignora se time específico não existir
          }
        }
      }
      console.log(`    ✅ ${pCount} jogadores cadastrados na categoria ${cat}`);
    }

    console.log(`  Total de jogadores no cache para este campeonato: ${Object.keys(playersCache).length}`);

    // 2. IMPORTAR LANCES E ESCALAÇÃO DE CADA PARTIDA
    for (const cat of tourney.categories) {
      console.log(`  Buscando súmulas/detalhes da categoria ${cat}...`);
      const detailsObj = await fetchJson(`https://copafacil-web.firebaseio.com/events/${cat}/details.json?auth=${token}`);
      if (!detailsObj) continue;

      let matchCount = 0;
      for (const [matchId, matchDetail] of Object.entries(detailsObj)) {
        if (!matchDetail || !matchDetail.list) continue;

        const partidaRef = tviDb.collection('campeonatos').doc(tourney.campId)
          .collection('partidas').doc(matchId);

        // Verificar se partida existe no Firestore
        const pSnap = await partidaRef.get();
        if (!pSnap.exists) continue;

        const partidaData = pSnap.data();
        const lancesRef = partidaRef.collection('lances');

        let minutoVirtual = 1;
        for (const [actionId, action] of Object.entries(matchDetail.list)) {
          // Tipos de lances no Copa Fácil:
          // ac 1: Gol
          // ac 2: Gol contra
          // ac 3: Cartão Amarelo
          // ac 4: Cartão Vermelho
          // ac 6: Substituição
          // ac 7: Jogador relacionado na súmula / escalação
          let tipoLance = null;
          let descricao = '';

          const pl1 = playersCache[action.pl_id1];
          const plNome = pl1 ? pl1.nome : (action.msg ? `Camisa ${action.msg}` : 'Jogador');

          if (action.ac === 1) {
            tipoLance = 'gol';
            descricao = `Gol marcado por ${plNome}`;
          } else if (action.ac === 2) {
            tipoLance = 'golContra';
            descricao = `Gol contra de ${plNome}`;
          } else if (action.ac === 3) {
            tipoLance = 'cartaoAmarelo';
            descricao = `Cartão amarelo para ${plNome}`;
          } else if (action.ac === 4) {
            tipoLance = 'cartaoVermelho';
            descricao = `Cartão vermelho para ${plNome}`;
          }

          if (tipoLance) {
            const min = action.min != null && action.min > 0 ? action.min : minutoVirtual++;
            await lancesRef.doc(actionId).set({
              id: actionId,
              partidaId: matchId,
              tipo: tipoLance,
              minuto: min,
              periodo: action.per || 1,
              timeId: action.team1 || '',
              timeNome: action.team1 === partidaData.timeAId ? partidaData.timeANome : partidaData.timeBNome,
              jogadorId: action.pl_id1 || '',
              jogadorNome: plNome,
              descricao: descricao,
              timestamp: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });

            totalLancesImported++;
          } else if (action.ac === 7 && action.team1 && action.pl_id1) {
            // Jogador relacionado na súmula (escalação)
            try {
              await tviDb.collection('campeonatos').doc(tourney.campId)
                .collection('times').doc(action.team1)
                .collection('jogadores').doc(action.pl_id1)
                .set({
                  numero: action.msg ? parseInt(action.msg, 10) : null
                }, { merge: true });
            } catch (e) {}
          }
        }
        matchCount++;
      }
      console.log(`    ✅ Súmulas de ${matchCount} partidas migradas em ${cat}`);
    }
  }

  console.log(`\n🎉 MIGRAÇÃO COMPLETA FINALIZADA!`);
  console.log(`Total de jogadores cadastrados: ${totalPlayersImported}`);
  console.log(`Total de lances cadastrados nas súmulas: ${totalLancesImported}`);
  process.exit(0);
}

run().catch(e => {
  console.error('Erro na migração:', e);
  process.exit(1);
});
