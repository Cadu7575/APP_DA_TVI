/**
 * calcular_classificacao_v2.js
 * Calcula a classificação de cada fase/grupo a partir das partidas.
 * E salva num formato compatível com o ClassificacaoService do App:
 * campeonatos/{cid}/classificacao/{timeId}
 */

const admin = require('firebase-admin');

const CAMPS = [
  { fs: 'copafacil_5fqd2', nome: 'Copa TVitapê 2026'          },
  { fs: 'copafacil_jcgq9', nome: 'Copa TVitapê 2025'          },
  { fs: 'copafacil_077g4', nome: 'Varzeano Itapetininga 2026' },
  { fs: 'copafacil_rmjb0', nome: 'Varzeano Itapetininga 2025' },
];

async function main() {
  console.log('=== CALCULANDO CLASSIFICAÇÃO (FORMATO TVI NEWS) ===\n');

  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  for (const camp of CAMPS) {
    console.log(`\n--- ${camp.nome} ---`);
    const campRef = db.collection('campeonatos').doc(camp.fs);

    // Lê todas as partidas
    const partidasSnap = await campRef.collection('partidas').get();

    // Agrupa partidas por fase
    const fases = {}; // faseId -> array de partidas

    for (const doc of partidasSnap.docs) {
      const p = doc.data();
      if (!p.timeAId || !p.timeBId) continue;
      if (p.status !== 'encerrada') continue;

      const faseId = p.faseId || 'geral';
      if (!fases[faseId]) fases[faseId] = [];
      fases[faseId].push(p);
    }

    let classificadosTotal = 0;
    const batch = db.batch();

    for (const [faseId, partidasFase] of Object.entries(fases)) {
      const acumuladores = {};

      for (const p of partidasFase) {
        const placarA = parseInt(p.placarA || 0);
        const placarB = parseInt(p.placarB || 0);

        if (!acumuladores[p.timeAId]) {
          acumuladores[p.timeAId] = { id: p.timeAId, nome: p.timeANome || `Time ${p.timeAId.substring(1,9)}`, J:0, V:0, E:0, D:0, GP:0, GC:0, P:0 };
        }
        if (!acumuladores[p.timeBId]) {
          acumuladores[p.timeBId] = { id: p.timeBId, nome: p.timeBNome || `Time ${p.timeBId.substring(1,9)}`, J:0, V:0, E:0, D:0, GP:0, GC:0, P:0 };
        }

        const tA = acumuladores[p.timeAId];
        const tB = acumuladores[p.timeBId];

        tA.J++; tB.J++;
        tA.GP += placarA; tA.GC += placarB;
        tB.GP += placarB; tB.GC += placarA;

        if (placarA > placarB) {
          tA.V++; tA.P += 3;
          tB.D++;
        } else if (placarB > placarA) {
          tB.V++; tB.P += 3;
          tA.D++;
        } else {
          tA.E++; tA.P++;
          tB.E++; tB.P++;
        }
      }

      for (const [timeId, stats] of Object.entries(acumuladores)) {
        const ref = campRef.collection('classificacao').doc(timeId);
        batch.set(ref, {
          timeId: timeId,
          timeNome: stats.nome,
          pontos: stats.P,
          jogos: stats.J,
          vitorias: stats.V,
          empates: stats.E,
          derrotas: stats.D,
          golsPro: stats.GP,
          golsContra: stats.GC,
          saldoGols: stats.GP - stats.GC,
          faseId: faseId
        });
        classificadosTotal++;
      }
    }

    await batch.commit();
    console.log(`  ✓ ${classificadosTotal} times salvos na coleção 'classificacao' do Firestore`);
  }

  console.log('\n✅ TUDO PRONTO!');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
