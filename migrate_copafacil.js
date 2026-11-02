/**
 * migrate_copafacil.js
 * Script de migração de dados da CopáFácil → Firebase Firestore do TVI News
 *
 * O script:
 * 1. Loga na CopáFácil com as credenciais do usuário (lalomoraes / L@lO2@25)
 * 2. Lê todos os campeonatos, times, jogadores, partidas e lances do Firestore deles
 * 3. Transforma para o schema do TVI News
 * 4. Importa no Firestore do TVI News (tvi-news)
 *
 * USO:
 *   node migrate_copafacil.js
 */

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, collection, getDocs, doc, setDoc, Timestamp } = require('firebase/firestore');
const admin = require('firebase-admin');
const path = require('path');

// ─── CONFIG COPAFÁCIL (fonte) ───────────────────────────────────────────────
const COPAFACIL_CONFIG = {
  apiKey: "AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0",
  authDomain: "copafacil-web.firebaseapp.com",
  databaseURL: "https://copafacil-web.firebaseio.com",
  projectId: "copafacil-web",
  storageBucket: "copafacil-web.appspot.com",
  messagingSenderId: "1084972798992",
  appId: "1:1084972798992:web:821f62c5b4373754c4e695",
  measurementId: "G-W2PPHLK289"
};

// ─── CREDENCIAIS DO USUÁRIO NA COPAFÁCIL ────────────────────────────────────
const COPAFACIL_EMAIL = "lalomoraes@copafacil.com";  // usuário: lalomoraes
const COPAFACIL_SENHA = "L@lO2@25";

// ─── INICIALIZAR COPAFÁCIL (client SDK para auth) ───────────────────────────
const cfApp = initializeApp(COPAFACIL_CONFIG, 'copafacil');
const cfAuth = getAuth(cfApp);
const cfDb = getFirestore(cfApp);

// ─── INICIALIZAR TVI NEWS (admin SDK para escrever) ─────────────────────────
// Coloque o arquivo de chave de serviço do projeto tvi-news nesta pasta
// Download em: Firebase Console → tvi-news → Configurações → Contas de serviço → Gerar nova chave privada
const SERVICE_ACCOUNT_PATH = path.join(__dirname, 'tvi-news-service-account.json');

let tviDb;

async function initTviAdmin() {
  try {
    const serviceAccount = require(SERVICE_ACCOUNT_PATH);
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: 'tvi-news'
    });
    tviDb = admin.firestore();
    console.log('✅ TVI News Admin SDK inicializado');
  } catch (e) {
    console.error('❌ Erro ao inicializar Admin SDK:', e.message);
    console.error('   → Certifique-se que o arquivo tvi-news-service-account.json está na mesma pasta');
    process.exit(1);
  }
}

// ─── MAPAS DE CONVERSÃO ─────────────────────────────────────────────────────

function mapEsporte(esporteCF) {
  const map = {
    'futebol': 'futebol',
    'futsal': 'futsal',
    'basquete': 'basquete',
    'volei': 'volei',
    'handebol': 'handebol',
    'soccer': 'futebol',
    'futbol': 'futebol',
    'basketball': 'basquete',
    'volleyball': 'volei',
    'handball': 'handebol',
  };
  const s = (esporteCF || 'futebol').toLowerCase();
  return map[s] || 'futebol';
}

function mapStatus(statusCF) {
  const map = {
    'aberto': 'inscricoesAbertas',
    'inscricoes': 'inscricoesAbertas',
    'em_andamento': 'emAndamento',
    'andamento': 'emAndamento',
    'encerrado': 'encerrado',
    'finalizado': 'encerrado',
    'cancelado': 'cancelado',
  };
  const s = (statusCF || '').toLowerCase().replace(/\s/g, '_');
  return map[s] || 'encerrado';
}

function mapTipoLance(tipoCF) {
  const map = {
    'gol': 'gol',
    'goal': 'gol',
    'cartao_amarelo': 'cartaoAmarelo',
    'amarelo': 'cartaoAmarelo',
    'yellow': 'cartaoAmarelo',
    'cartao_vermelho': 'cartaoVermelho',
    'vermelho': 'cartaoVermelho',
    'red': 'cartaoVermelho',
    'substituicao': 'substituicao',
    'sub': 'substituicao',
    'lesao': 'lesao',
    'contra': 'golContra',
    'penalti': 'penalti',
    'penalty': 'penalti',
  };
  const s = (tipoCF || '').toLowerCase().replace(/[\s-]/g, '_');
  return map[s] || 'ocorrencia';
}

// ─── HELPER: Converte Timestamp ou string em Timestamp do Admin SDK ─────────
function toAdminTs(val) {
  if (!val) return null;
  if (val && val.toDate) return admin.firestore.Timestamp.fromDate(val.toDate());
  if (val instanceof Date) return admin.firestore.Timestamp.fromDate(val);
  if (typeof val === 'string') {
    const d = new Date(val);
    if (!isNaN(d)) return admin.firestore.Timestamp.fromDate(d);
  }
  return null;
}

// ─── PRINCIPAIS FUNÇÕES DE MIGRAÇÃO ─────────────────────────────────────────

async function migrarCampeonatos(uid) {
  console.log('\n📋 Buscando campeonatos do usuário...');

  // Na CopáFácil, campeonatos do organizador ficam em /campeonatos onde organizadorId == uid
  const snap = await getDocs(collection(cfDb, 'campeonatos'));
  const todos = snap.docs.map(d => ({ id: d.id, ...d.data() }));

  // Filtra apenas os campeonatos do usuário logado
  const meus = todos.filter(c =>
    c.organizadorId === uid ||
    c.userId === uid ||
    c.uid === uid ||
    c.criadorId === uid
  );

  if (meus.length === 0) {
    // Tenta sem filtro — talvez o campo seja diferente
    console.log(`   ⚠️  Nenhum campeonato filtrado por organizadorId=${uid}`);
    console.log(`   📋 Total de campeonatos no Firestore deles: ${todos.length}`);
    console.log(`   🔑 Campos disponíveis no primeiro: ${Object.keys(todos[0] || {}).join(', ')}`);
    return todos.slice(0, 20); // pega os primeiros 20 para inspecionar
  }

  console.log(`   ✅ ${meus.length} campeonatos encontrados`);
  return meus;
}

async function migrarCampeonato(cf_campeonato, organizadorNome) {
  const cfId = cf_campeonato.id;
  console.log(`\n🏆 Migrando: ${cf_campeonato.nome || cf_campeonato.name || cfId}`);

  // Gera ID no TVI baseado no nome (legível)
  const nome = cf_campeonato.nome || cf_campeonato.name || 'Campeonato';
  const tviId = nome.toLowerCase()
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_|_$/g, '')
    + '_' + cfId.substring(0, 6);

  // ─── Campeonato ───────────────────────────────────────────────────────────
  const campeonato = {
    nome: nome,
    descricao: cf_campeonato.descricao || cf_campeonato.description || '',
    esporte: mapEsporte(cf_campeonato.esporte || cf_campeonato.sport || cf_campeonato.modalidade),
    status: mapStatus(cf_campeonato.status || cf_campeonato.situacao),
    organizadorId: 'lalomoraes_migrado',
    organizadorNome: organizadorNome || 'Lalo Moraes',
    dataInicio: toAdminTs(cf_campeonato.dataInicio || cf_campeonato.startDate || cf_campeonato.inicio),
    dataFim: toAdminTs(cf_campeonato.dataFim || cf_campeonato.endDate || cf_campeonato.fim),
    local: cf_campeonato.local || cf_campeonato.cidade || cf_campeonato.location || null,
    logoUrl: cf_campeonato.logo || cf_campeonato.logoUrl || cf_campeonato.imagem || null,
    categorias: cf_campeonato.categorias || cf_campeonato.categories || [],
    maxTimes: cf_campeonato.maxTimes || cf_campeonato.numEquipes || 16,
    patrocinadores: cf_campeonato.patrocinadores || [],
    criadoEm: toAdminTs(cf_campeonato.criadoEm || cf_campeonato.createdAt) || admin.firestore.Timestamp.now(),
    migradoDeCopafacil: true,
    copafacilId: cfId,
  };

  await tviDb.collection('campeonatos').doc(tviId).set(campeonato);
  console.log(`   ✅ Campeonato salvo: ${tviId}`);

  // ─── Times ────────────────────────────────────────────────────────────────
  let timesMap = {}; // cfTimeId → tviTimeId
  try {
    const timesSnap = await getDocs(collection(cfDb, 'campeonatos', cfId, 'equipes'));
    const timesSnap2 = timesSnap.empty ? await getDocs(collection(cfDb, 'campeonatos', cfId, 'times')) : timesSnap;

    if (!timesSnap2.empty) {
      console.log(`   👕 ${timesSnap2.size} times encontrados`);
      for (const tDoc of timesSnap2.docs) {
        const td = tDoc.data();
        const nomeTime = td.nome || td.name || td.nomeEquipe || 'Time';
        const tviTimeId = tDoc.id;
        timesMap[tDoc.id] = tviTimeId;

        await tviDb.collection('campeonatos').doc(tviId)
          .collection('times').doc(tviTimeId).set({
            campeonatoId: tviId,
            nome: nomeTime,
            logoUrl: td.logo || td.logoUrl || td.escudo || null,
            categoria: td.categoria || td.category || null,
            responsavelNome: td.responsavel || td.representante || td.contato || 'Responsável',
            responsavelTelefone: td.telefone || td.phone || null,
            organizadorId: 'lalomoraes_migrado',
            criadoEm: toAdminTs(td.criadoEm || td.createdAt) || admin.firestore.Timestamp.now(),
          });
      }
      console.log(`   ✅ ${timesSnap2.size} times migrados`);
    } else {
      console.log(`   ℹ️  Nenhum time encontrado (subcoleção 'equipes'/'times' vazia)`);
    }
  } catch (e) {
    console.log(`   ⚠️  Erro ao buscar times: ${e.message}`);
  }

  // ─── Jogadores ────────────────────────────────────────────────────────────
  try {
    const jogsSnap = await getDocs(collection(cfDb, 'campeonatos', cfId, 'jogadores'));
    if (!jogsSnap.empty) {
      console.log(`   👤 ${jogsSnap.size} jogadores encontrados`);
      const batch = tviDb.batch();
      for (const jDoc of jogsSnap.docs) {
        const jd = jDoc.data();
        const timeId = timesMap[jd.equipeId || jd.timeId] || jd.equipeId || jd.timeId || 'sem_time';
        const ref = tviDb.collection('campeonatos').doc(tviId)
          .collection('times').doc(timeId)
          .collection('jogadores').doc(jDoc.id);  // mantém mesmo ID
        batch.set(ref, {
          campeonatoId: tviId,
          timeId: timeId,
          nome: jd.nome || jd.name || jd.nomeJogador || 'Jogador',
          apelido: jd.apelido || jd.nickname || null,
          numero: jd.numero || jd.camisa || jd.number || null,
          posicao: jd.posicao || jd.position || null,
          fotoUrl: jd.foto || jd.fotoUrl || jd.photo || null,
          cpf: jd.cpf || jd.documento || null,
          criadoEm: toAdminTs(jd.criadoEm || jd.createdAt) || admin.firestore.Timestamp.now(),
        });
      }
      await batch.commit();
      console.log(`   ✅ ${jogsSnap.size} jogadores migrados`);
    }
  } catch (e) {
    console.log(`   ⚠️  Erro ao buscar jogadores: ${e.message}`);
  }

  // ─── Partidas ─────────────────────────────────────────────────────────────
  try {
    const partidasSnap = await getDocs(collection(cfDb, 'campeonatos', cfId, 'partidas'));
    const jogosSnap = partidasSnap.empty
      ? await getDocs(collection(cfDb, 'campeonatos', cfId, 'jogos'))
      : partidasSnap;

    if (!jogosSnap.empty) {
      console.log(`   ⚽ ${jogosSnap.size} partidas encontradas`);
      for (const pDoc of jogosSnap.docs) {
        const pd = pDoc.data();
        const timeAId = timesMap[pd.equipeAId || pd.timeAId || pd.mandanteId] || pd.equipeAId || pd.timeAId || 'a';
        const timeBId = timesMap[pd.equipeBId || pd.timeBId || pd.visitanteId] || pd.equipeBId || pd.timeBId || 'b';

        await tviDb.collection('campeonatos').doc(tviId)
          .collection('partidas').doc(pDoc.id).set({
            campeonatoId: tviId,
            faseId: pd.faseId || pd.fase || 'geral',
            grupoId: pd.grupoId || pd.grupo || null,
            timeAId: timeAId,
            timeANome: pd.equipeANome || pd.timeANome || pd.mandante || 'Time A',
            timeBId: timeBId,
            timeBNome: pd.equipeBNome || pd.timeBNome || pd.visitante || 'Time B',
            placarA: pd.placarA || pd.golsA || pd.mandanteGols || 0,
            placarB: pd.placarB || pd.golsB || pd.visitanteGols || 0,
            status: mapStatus(pd.status || pd.situacao || 'encerrado'),
            arbitroId: pd.arbitroId || null,
            arbitroNome: pd.arbitroNome || pd.arbitro || null,
            dataHora: toAdminTs(pd.dataHora || pd.data || pd.date || pd.horario),
            local: pd.local || pd.campo || pd.stadium || null,
            rodada: pd.rodada || pd.rodada || 1,
            editadoPorAdmin: false,
            copafacilId: pDoc.id,
          });

        // ─── Lances da partida ─────────────────────────────────────────────
        try {
          const lancesSnap = await getDocs(
            collection(cfDb, 'campeonatos', cfId, 'partidas', pDoc.id, 'lances')
          );
          const eventosSnap = lancesSnap.empty
            ? await getDocs(collection(cfDb, 'campeonatos', cfId, 'jogos', pDoc.id, 'eventos'))
            : lancesSnap;

          if (!eventosSnap.empty) {
            const lb = tviDb.batch();
            for (const lDoc of eventosSnap.docs) {
              const ld = lDoc.data();
              const ref = tviDb.collection('campeonatos').doc(tviId)
                .collection('partidas').doc(pDoc.id)
                .collection('lances').doc(lDoc.id);
              lb.set(ref, {
                partidaId: pDoc.id,
                campeonatoId: tviId,
                tipo: mapTipoLance(ld.tipo || ld.type || ld.evento),
                jogadorId: ld.jogadorId || ld.playerId || null,
                jogadorNome: ld.jogadorNome || ld.jogador || ld.player || null,
                jogadorSaiId: ld.jogadorSaiId || null,
                jogadorSaiNome: ld.jogadorSaiNome || ld.jogadorSai || null,
                timeId: timesMap[ld.equipeId || ld.timeId] || ld.equipeId || ld.timeId || null,
                minuto: ld.minuto || ld.minute || ld.tempo || 0,
                descricao: ld.descricao || ld.obs || null,
                registradoPorId: ld.arbitroId || 'migrado',
                timestamp: toAdminTs(ld.timestamp || ld.criadoEm) || admin.firestore.Timestamp.now(),
              });
            }
            await lb.commit();
          }
        } catch (e) {
          // Silencioso — nem toda partida tem lances
        }
      }
      console.log(`   ✅ ${jogosSnap.size} partidas migradas`);
    }
  } catch (e) {
    console.log(`   ⚠️  Erro ao buscar partidas: ${e.message}`);
  }

  return tviId;
}

// ─── MAIN ────────────────────────────────────────────────────────────────────

async function main() {
  console.log('🚀 Iniciando migração CopáFácil → TVI News\n');

  // 1. Inicializa Admin SDK do TVI
  await initTviAdmin();

  // 2. Login na CopáFácil
  console.log('🔐 Fazendo login na CopáFácil...');
  let uid, displayName;
  try {
    const cred = await signInWithEmailAndPassword(cfAuth, COPAFACIL_EMAIL, COPAFACIL_SENHA);
    uid = cred.user.uid;
    displayName = cred.user.displayName || 'Lalo Moraes';
    console.log(`   ✅ Logado! UID: ${uid}, Nome: ${displayName}`);
  } catch (e) {
    console.error('   ❌ Falha no login:', e.message);
    console.error('   → Verifique o email e senha da CopáFácil');
    process.exit(1);
  }

  // 3. Busca campeonatos
  const campeonatos = await migrarCampeonatos(uid);

  if (!campeonatos || campeonatos.length === 0) {
    console.log('\n❌ Nenhum campeonato encontrado para este usuário.');
    process.exit(0);
  }

  console.log(`\n📋 ${campeonatos.length} campeonatos para migrar:`);
  campeonatos.forEach((c, i) => {
    console.log(`   ${i + 1}. ${c.nome || c.name || c.id}`);
  });

  // 4. Migra cada campeonato
  const migrados = [];
  for (const c of campeonatos) {
    const tviId = await migrarCampeonato(c, displayName);
    migrados.push({ original: c.nome || c.id, tviId });
  }

  // 5. Relatório final
  console.log('\n\n✅ MIGRAÇÃO CONCLUÍDA!\n');
  console.log('Campeonatos migrados:');
  migrados.forEach(m => {
    console.log(`   • ${m.original} → ID no TVI: ${m.tviId}`);
  });
  console.log('\nAbra o app TVI e veja a aba Campeonatos! 🏆');

  process.exit(0);
}

main().catch(e => {
  console.error('\n❌ Erro fatal:', e);
  process.exit(1);
});
