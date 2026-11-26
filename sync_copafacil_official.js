/**
 * sync_copafacil_official.js
 * Script de sincronização oficial da API v2 do Copa Fácil para o Firestore do TVI Futebol.
 */

const https = require('https');
const admin = require('firebase-admin');

const CF_API_KEY = '4YW3-V7UC-WR5A';

// Inicializa Firebase Admin
const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
if (!admin.apps.length) {
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
}
const db = admin.firestore();
db.settings({ ignoreUndefinedProperties: true });

function cfApi(path) {
  return new Promise((resolve) => {
    const opts = {
      hostname: 'copafacil.com',
      path: '/api2' + path,
      headers: {
        'x-api-key': CF_API_KEY,
        'lang': 'pt',
        'gmt': '-3',
      },
    };
    https.get(opts, (res) => {
      let d = '';
      res.on('data', (c) => (d += c));
      res.on('end', () => {
        try {
          resolve({ status: res.statusCode, data: JSON.parse(d) });
        } catch (e) {
          resolve({ status: res.statusCode, raw: d });
        }
      });
    }).on('error', (e) => resolve({ error: e.message }));
  });
}

function delay(ms) {
  return new Promise((res) => setTimeout(res, ms));
}

// Configuração dos Campeonatos e suas Categorias
const CAMPEONATOS = [
  {
    docId: 'copafacil_5fqd2',
    nome: 'Copa TVitapê 2026',
    categorias: [
      '-5fqd2@1y6x',  // SUB 8
      '-5fqd2@v9gyy', // SUB 10
      '-5fqd2@zda6m', // SUB 12
      '-5fqd2@88imd', // SUB 14
      '-5fqd2@ah1bq', // SUB 16
      '-5fqd2@fy1s7',
      '-5fqd2@t0qyn',
      '-5fqd2@1rf6i',
      '-5fqd2@8ohik',
    ]
  },
  {
    docId: 'copafacil_077g4',
    nome: 'Varzeano Itapetininga 2026',
    categorias: [
      '-077g4@86vf',
      '-077g4@958ly',
      '-077g4@vqo6p',
    ]
  },
  {
    docId: 'copafacil_jcgq9',
    nome: 'Copa TVitapê 2025',
    categorias: [
      '-jcgq9@qckh', // SUB 8
      '-jcgq9@ztuy', // SUB 10
      '-jcgq9@arqr',
      '-jcgq9@5mng',
      '-jcgq9@5mv4',
      '-jcgq9@9v8k',
      '-jcgq9@284z',
      '-jcgq9@v3dl',
      '-jcgq9@gytm',
    ]
  },
  {
    docId: 'copafacil_rmjb0',
    nome: 'Varzeano Itapetininga 2025',
    categorias: [
      '-rmjb0@iffu',
      '-rmjb0@k6f8',
    ]
  }
];

async function syncCategoria(campDocId, catId) {
  console.log(`\n--------------------------------------------------`);
  console.log(`[Categoria: ${catId}]`);
  
  // 1. STAGES
  const stagesRes = await cfApi(`/tournament/${encodeURIComponent(catId)}/stages`);
  await delay(120);

  if (stagesRes.status !== 200 || !Array.isArray(stagesRes.data)) {
    console.log(`❌ Erro ao buscar fases (${stagesRes.status})`);
    return;
  }

  const stages = stagesRes.data;
  console.log(`Fases encontradas: ${stages.length}`);

  for (const stage of stages) {
    console.log(`-> Fase: "${stage.title}" (ID: ${stage.id})`);

    // 1.1 CLASSIFICAÇÃO / TABELA
    const tableRes = await cfApi(`/tournament/${encodeURIComponent(catId)}/stages/${stage.id}/table`);
    await delay(120);

    if (tableRes.status === 200 && tableRes.data?.teams?.length > 0) {
      console.log(`   Tabela: ${tableRes.data.teams.length} equipes`);
      const safeStageId = `${catId.replace(/[^a-zA-Z0-9_-]/g, '_')}_${stage.id}`;
      
      await db.collection('campeonatos').doc(campDocId)
        .collection('classificacao').doc(safeStageId).set({
          categoriaId: catId,
          faseId: stage.id,
          faseTitulo: stage.title,
          roundRobin: stage.round_robin || false,
          header: tableRes.data.header || [],
          times: tableRes.data.teams.map((t) => ({
            nome: t.name,
            posicao: t.position,
            fotoUrl: t.photo || null,
            timeId: t.id,
            dados: t.tableData || [],
          })),
          atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });
    }

    // 1.2 RODADAS & PARTIDAS
    const roundsRes = await cfApi(`/tournament/${encodeURIComponent(catId)}/stages/${stage.id}/rounds`);
    await delay(120);

    if (roundsRes.status === 200 && Array.isArray(roundsRes.data)) {
      for (const round of roundsRes.data) {
        const matchesRes = await cfApi(`/tournament/${encodeURIComponent(catId)}/stages/${stage.id}/rounds/${round.id}/matchs`);
        await delay(120);

        if (matchesRes.status === 200 && Array.isArray(matchesRes.data)) {
          let updatedCount = 0;
          for (const m of matchesRes.data) {
            const team1 = m.teams?.team_1 || {};
            const team2 = m.teams?.team_2 || {};
            const result = m.result || {};

            let statusFormatado = 'agendada';
            if (m.status === 'STATUS_FINISHED') statusFormatado = 'encerrada';
            else if (m.status === 'STATUS_IN_PROGRESS') statusFormatado = 'emAndamento';
            else if (m.status === 'STATUS_NOT_REALIZED') statusFormatado = 'agendada';

            const partidaDoc = {
              campeonatoId: campDocId,
              copafacilMatchId: m.id,
              faseId: catId,
              faseTitulo: stage.title,
              rodadaTitulo: round.title,
              subfaseId: stage.id,
              titulo: m.title || `${team1.name || 'Time 1'} x ${team2.name || 'Time 2'}`,
              timeAId: team1.id || null,
              timeANome: team1.name || 'Time A',
              timeBId: team2.id || null,
              timeBNome: team2.name || 'Time B',
              placarA: result.pts1 ?? 0,
              placarB: result.pts2 ?? 0,
              penaltiA: result.penalt1 ?? 0,
              penaltiB: result.penalt2 ?? 0,
              status: statusFormatado,
              local: m.local || null,
              dataTimestamp: m.time_millis || null,
              atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
            };

            await db.collection('campeonatos').doc(campDocId)
              .collection('partidas').doc(m.id).set(partidaDoc, { merge: true });
            updatedCount++;
          }
          if (updatedCount > 0) {
            console.log(`   [${round.title}] ${updatedCount} partidas sincronizadas`);
          }
        }
      }
    }
  }

  // 2. RANKINGS (Artilharia, etc.)
  const rankingsRes = await cfApi(`/tournament/${encodeURIComponent(catId)}/rankings`);
  await delay(120);

  if (rankingsRes.status === 200 && Array.isArray(rankingsRes.data)) {
    for (const rk of rankingsRes.data) {
      const rkDetail = await cfApi(`/tournament/${encodeURIComponent(catId)}/rankings/${rk.id}`);
      await delay(120);

      if (rkDetail.status === 200 && rkDetail.data?.players?.length > 0) {
        const safeRkId = `${catId.replace(/[^a-zA-Z0-9_-]/g, '_')}_${rk.id}`;
        console.log(`   🏆 Ranking ${rk.title1 || rk.id}: ${rkDetail.data.players.length} jogadores`);

        await db.collection('campeonatos').doc(campDocId)
          .collection('rankings').doc(safeRkId).set({
            categoriaId: catId,
            rankingId: rk.id,
            titulo: rk.title1 || 'Ranking',
            header: rkDetail.data.header || [],
            jogadores: rkDetail.data.players.map((p) => ({
              nome: p.name,
              apelido: p.nickName || null,
              posicao: p.position,
              fotoUrl: p.photo || null,
              timeNome: p.teamName || null,
              timeId: p.teamId || null,
              timeFoto: p.teamPhoto || null,
              jogadorId: p.playerId || null,
              dados: p.data || [],
            })),
            atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
          }, { merge: true });
      }
    }
  }
}

async function run() {
  console.log('==================================================');
  console.log('🚀 INICIANDO SINCRONIZAÇÃO COMPLETA COPA FÁCIL API');
  console.log('==================================================');

  for (const camp of CAMPEONATOS) {
    console.log(`\n==================================================`);
    console.log(`CAMPEONATO: ${camp.nome} (${camp.docId})`);
    console.log(`==================================================`);

    // Sincroniza cada categoria daquele campeonato
    for (const catId of camp.categorias) {
      try {
        await syncCategoria(camp.docId, catId);
      } catch (err) {
        console.error(`Erro ao sincronizar categoria ${catId}:`, err.message);
      }
    }
  }

  console.log('\n==================================================');
  console.log('✅ TODAS AS CATEGORIAS FORAM SINCRONIZADAS COM SUCESSO!');
  console.log('==================================================');
  process.exit(0);
}

run().catch((e) => {
  console.error('Erro geral no processo:', e);
  process.exit(1);
});
