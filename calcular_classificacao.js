/**
 * calcular_classificacao.js
 * Calcula a classificação de cada fase/grupo a partir das partidas
 * já importadas no Firestore do TVI News.
 * 
 * Salva em: campeonatos/{id}/classificacao/{faseId}
 */

const admin = require('firebase-admin');

const CAMPS = [
  { fs: 'copafacil_5fqd2', nome: 'Copa TVitapê 2026'          },
  { fs: 'copafacil_jcgq9', nome: 'Copa TVitapê 2025'          },
  { fs: 'copafacil_077g4', nome: 'Varzeano Itapetininga 2026' },
  { fs: 'copafacil_rmjb0', nome: 'Varzeano Itapetininga 2025' },
];

// Mapa de faseId → nome legível (baseado no sufixo do grupo)
// Será preenchido dinamicamente com base nos dados
function nomeDaFase(faseId) {
  if (!faseId) return 'Geral';
  // Formato: -5fqd2@1y6x  → pega o sufixo após @
  const sufixo = faseId.split('@')[1] || faseId;
  return `Fase ${sufixo}`;
}

async function main() {
  console.log('=== CALCULANDO CLASSIFICAÇÃO DAS PARTIDAS ===\n');

  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();

  for (const camp of CAMPS) {
    console.log(`\n--- ${camp.nome} ---`);
    const campRef = db.collection('campeonatos').doc(camp.fs);

    // Lê todas as partidas
    const partidasSnap = await campRef.collection('partidas').get();
    console.log(`  Total partidas: ${partidasSnap.size}`);

    // Agrupa partidas por fase
    const fases = {}; // faseId → Map<teamId, {nome, stats}>

    for (const doc of partidasSnap.docs) {
      const p = doc.data();
      if (!p.timeAId || !p.timeBId) continue;
      if (p.status !== 'encerrada') continue;

      const faseId = p.faseId || 'geral';
      if (!fases[faseId]) fases[faseId] = {};

      const fase = fases[faseId];
      const placarA = parseInt(p.placarA || 0);
      const placarB = parseInt(p.placarB || 0);

      // Inicializa times se não existem
      if (!fase[p.timeAId]) {
        fase[p.timeAId] = {
          teamId: p.timeAId,
          nome: p.timeANome || p.timeAId.substring(1, 9),
          J: 0, V: 0, E: 0, D: 0, GP: 0, GC: 0, P: 0
        };
      }
      if (!fase[p.timeBId]) {
        fase[p.timeBId] = {
          teamId: p.timeBId,
          nome: p.timeBNome || p.timeBId.substring(1, 9),
          J: 0, V: 0, E: 0, D: 0, GP: 0, GC: 0, P: 0
        };
      }

      const tA = fase[p.timeAId];
      const tB = fase[p.timeBId];

      // Atualiza stats
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

    console.log(`  Fases encontradas: ${Object.keys(fases).length}`);
    let totalClassSalva = 0;

    for (const [faseId, times] of Object.entries(fases)) {
      const classificacao = Object.values(times).map(t => ({
        ...t,
        SG: t.GP - t.GC,
      }));

      // Ordena: P → SG → GP
      classificacao.sort((a, b) => {
        if (b.P !== a.P) return b.P - a.P;
        if (b.SG !== a.SG) return b.SG - a.SG;
        return b.GP - a.GP;
      });

      // Atribui posições
      classificacao.forEach((t, i) => { t.posicao = i + 1; });

      // Salva no Firestore
      await campRef.collection('classificacao').doc(faseId.replace(/[@]/g, '_')).set({
        faseId,
        nome: nomeDaFase(faseId),
        campeonatoId: camp.fs,
        atualizadoEm: admin.firestore.FieldValue.serverTimestamp(),
        totalTimes: classificacao.length,
        times: classificacao.map(t => ({
          teamId: t.teamId,
          nome: t.nome,
          posicao: t.posicao,
          pontos: t.P,
          jogos: t.J,
          vitorias: t.V,
          empates: t.E,
          derrotas: t.D,
          golsPro: t.GP,
          golsContra: t.GC,
          saldoGols: t.SG,
        })),
      });
      totalClassSalva++;

      // Mostra top 3
      console.log(`  Fase ${faseId}: ${classificacao.length} times`);
      classificacao.slice(0, 3).forEach(t =>
        console.log(`    ${t.posicao}. ${t.nome.padEnd(20)} ${t.P}pts J:${t.J} V:${t.V} E:${t.E} D:${t.D} ${t.GP}:${t.GC} SG:${t.SG}`)
      );
    }

    console.log(`  ✓ ${totalClassSalva} classificações salvas`);
  }

  console.log('\n✅ CLASSIFICAÇÃO CALCULADA E SALVA!');
  process.exit(0);
}

main().catch(e => { console.error('Erro:', e.message); process.exit(1); });
