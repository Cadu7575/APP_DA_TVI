const admin = require('firebase-admin');
const sa = require('./tvi-news-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function fixAllPrefixNames() {
  const camps = ['copafacil_5fqd2', 'copafacil_077g4', 'copafacil_jcgq9', 'copafacil_rmjb0'];

  for (const c of camps) {
    console.log(`\n=== PROCESSANDO ${c} ===`);
    const timesSnap = await db.collection('campeonatos').doc(c).collection('times').get();
    const timeMap = {};

    timesSnap.docs.forEach(doc => {
      const data = doc.data();
      const name = (data.nome || '').trim();
      if (name && !name.startsWith('-O')) {
        timeMap[doc.id] = name;
        timeMap[doc.id.substring(0, 8)] = name;
        timeMap[doc.id.substring(0, 9)] = name;
        timeMap[doc.id.substring(0, 10)] = name;
      }
    });

    console.log(`Dicionario montado com ${Object.keys(timeMap).length} entradas`);

    // Partidas
    const pSnap = await db.collection('campeonatos').doc(c).collection('partidas').get();
    let pBatch = db.batch();
    let pUpdated = 0;

    for (const doc of pSnap.docs) {
      const d = doc.data();
      const updates = {};

      if (d.timeANome && d.timeANome.startsWith('-O')) {
        const found = timeMap[d.timeAId] || timeMap[d.timeANome] ||
                      timeMap[(d.timeAId || '').substring(0, 8)] ||
                      timeMap[(d.timeAId || '').substring(0, 9)] ||
                      timeMap[(d.timeAId || '').substring(0, 10)];
        if (found) updates.timeANome = found;
      }

      if (d.timeBNome && d.timeBNome.startsWith('-O')) {
        const found = timeMap[d.timeBId] || timeMap[d.timeBNome] ||
                      timeMap[(d.timeBId || '').substring(0, 8)] ||
                      timeMap[(d.timeBId || '').substring(0, 9)] ||
                      timeMap[(d.timeBId || '').substring(0, 10)];
        if (found) updates.timeBNome = found;
      }

      if (Object.keys(updates).length > 0) {
        pBatch.update(doc.ref, updates);
        pUpdated++;
        if (pUpdated % 400 === 0) {
          await pBatch.commit();
          pBatch = db.batch();
        }
      }
    }
    if (pUpdated % 400 !== 0) await pBatch.commit();
    console.log(`Partidas corrigidas: ${pUpdated}`);

    // Classificacao
    const cSnap = await db.collection('campeonatos').doc(c).collection('classificacao').get();
    let cBatch = db.batch();
    let cUpdated = 0;

    for (const doc of cSnap.docs) {
      const d = doc.data();
      const updates = {};

      if (d.timeNome && d.timeNome.startsWith('-O')) {
        const found = timeMap[d.timeId] || timeMap[d.timeNome] ||
                      timeMap[(d.timeId || '').substring(0, 8)] ||
                      timeMap[(d.timeId || '').substring(0, 9)] ||
                      timeMap[(d.timeId || '').substring(0, 10)];
        if (found) updates.timeNome = found;
      }

      if (Object.keys(updates).length > 0) {
        cBatch.update(doc.ref, updates);
        cUpdated++;
        if (cUpdated % 400 === 0) {
          await cBatch.commit();
          cBatch = db.batch();
        }
      }
    }
    if (cUpdated % 400 !== 0) await cBatch.commit();
    console.log(`Classificacao corrigida: ${cUpdated}`);
  }

  console.log('\nFinalizado com sucesso!');
  process.exit(0);
}

fixAllPrefixNames().catch(e => { console.error(e); process.exit(1); });
