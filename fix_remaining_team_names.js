const admin = require('firebase-admin');
const fs = require('fs');

const sa = require('./tvi-news-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// Known mapping discovered
const HARDCODED_MAP = {
  '-OWLA86YSdbjsg43C92h': { name: 'Transcarvalho SC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLA86YSdbjsg43C92h.jpg?alt=media&token=1&m=1753792742034' },
  '-OWLA86Y': { name: 'Transcarvalho SC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLA86YSdbjsg43C92h.jpg?alt=media&token=1&m=1753792742034' },
  '-OWLACpAfHV6ExdIVzlS': { name: 'CBF/Retifica do Paulinho', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLACpAfHV6ExdIVzlS.jpg?alt=media&token=1&m=1753797251175' },
  '-OWLACpA': { name: 'CBF/Retifica do Paulinho', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLACpAfHV6ExdIVzlS.jpg?alt=media&token=1&m=1753797251175' },
  '-OWLAOqnv7ZsKIS3-9en': { name: 'Clube Venâncio Ayres', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLAOqnv7ZsKIS3-9en.jpg?alt=media&token=1&m=1753792731381' },
  '-OWLAOqn': { name: 'Clube Venâncio Ayres', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLAOqnv7ZsKIS3-9en.jpg?alt=media&token=1&m=1753792731381' },
  '-OWLASRQhWP4uXAcSWzs': { name: 'Ótica + Visão FC/C.S. Telecom', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLASRQhWP4uXAcSWzs.jpg?alt=media&token=1&m=1753792725337' },
  '-OWLASRQ': { name: 'Ótica + Visão FC/C.S. Telecom', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLASRQhWP4uXAcSWzs.jpg?alt=media&token=1&m=1753792725337' },
  '-OWLAW6n3QxRUKLVkW0a': { name: 'Sub Véio', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLAW6n3QxRUKLVkW0a.jpg?alt=media&token=1&m=1753792718170' },
  '-OWLAW6n': { name: 'Sub Véio', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLAW6n3QxRUKLVkW0a.jpg?alt=media&token=1&m=1753792718170' },
  '-OWLAW6n3Q': { name: 'Sub Véio', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLAW6n3QxRUKLVkW0a.jpg?alt=media&token=1&m=1753792718170' },
  '-OWLA9LIOoea22hbavvw': { name: 'Capela do Alto', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLA9LIOoea22hbavvw.jpg?alt=media&token=1&m=1753792799491' },
  '-OWLA9LI': { name: 'Capela do Alto', photo: 'https://copafacil-storage.b-cdn.net/events%2F-jcgq9%2F284z%2Fteams%2F-OWLA9LIOoea22hbavvw.jpg?alt=media&token=1&m=1753792799491' },
  '-OWLGfd2_OX8K603cjpU': { name: 'Santa FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OWLGfd2_OX8K603cjpU.jpg?alt=media&token=1&m=1785240846573' },
  '-OWLGfd2_O': { name: 'Santa FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OWLGfd2_OX8K603cjpU.jpg?alt=media&token=1&m=1785240846573' }
};

async function run() {
  const camps = ['copafacil_jcgq9', 'copafacil_rmjb0', 'copafacil_077g4', 'copafacil_5fqd2'];
  
  for (const c of camps) {
    console.log(`\n=== Corrigindo ${c} ===`);
    
    // 1. Partidas
    const pSnap = await db.collection('campeonatos').doc(c).collection('partidas').get();
    let pBatch = db.batch();
    let pCount = 0;
    
    pSnap.docs.forEach(doc => {
      const d = doc.data();
      const updates = {};
      
      const tAInfo = HARDCODED_MAP[d.timeAId] || HARDCODED_MAP[d.timeANome];
      if (tAInfo) {
        if (d.timeANome !== tAInfo.name) updates.timeANome = tAInfo.name;
        if (!d.timeALogo && tAInfo.photo) updates.timeALogo = tAInfo.photo;
      }
      
      const tBInfo = HARDCODED_MAP[d.timeBId] || HARDCODED_MAP[d.timeBNome];
      if (tBInfo) {
        if (d.timeBNome !== tBInfo.name) updates.timeBNome = tBInfo.name;
        if (!d.timeBLogo && tBInfo.photo) updates.timeBLogo = tBInfo.photo;
      }
      
      if (Object.keys(updates).length > 0) {
        pBatch.update(doc.ref, updates);
        pCount++;
      }
    });
    
    if (pCount > 0) {
      await pBatch.commit();
      console.log(`  Partidas atualizadas: ${pCount}`);
    } else {
      console.log(`  Nenhuma partida precisou de atualização.`);
    }

    // 2. Classificação
    const cSnap = await db.collection('campeonatos').doc(c).collection('classificacao').get();
    let cBatch = db.batch();
    let cCount = 0;
    
    cSnap.docs.forEach(doc => {
      const d = doc.data();
      const updates = {};
      
      const tInfo = HARDCODED_MAP[d.timeId] || HARDCODED_MAP[d.timeNome];
      if (tInfo) {
        if (d.timeNome !== tInfo.name) updates.timeNome = tInfo.name;
      }
      
      if (Object.keys(updates).length > 0) {
        cBatch.update(doc.ref, updates);
        cCount++;
      }
    });
    
    if (cCount > 0) {
      await cBatch.commit();
      console.log(`  Classificação atualizada: ${cCount}`);
    } else {
      console.log(`  Nenhuma classificação precisou de atualização.`);
    }

    // 3. Inserir nos Times se não existir
    for (const [id, info] of Object.entries(HARDCODED_MAP)) {
      if (id.length > 15) { // full ID
        const tDoc = await db.collection('campeonatos').doc(c).collection('times').doc(id).get();
        if (!tDoc.exists) {
          // Check if it belongs to this championship's matches
          const matchCheck = await db.collection('campeonatos').doc(c).collection('partidas')
            .where('timeAId', '==', id).limit(1).get();
          if (matchCheck.size > 0) {
            await tDoc.ref.set({
              id: id,
              nome: info.name,
              escudoUrl: info.photo,
              logoUrl: info.photo,
              campeonatoId: c,
              categoria: matchCheck.docs[0].data().categoria || 'Geral',
              criadoEm: admin.firestore.FieldValue.serverTimestamp()
            }, { merge: true });
            console.log(`  Time adicionado na colecao 'times': ${info.name} (${id})`);
          }
        } else if (tDoc.data().nome !== info.name) {
          await tDoc.ref.update({
            nome: info.name,
            escudoUrl: info.photo,
            logoUrl: info.photo
          });
          console.log(`  Time atualizado na colecao 'times': ${info.name}`);
        }
      }
    }
  }
  
  console.log('\nFinalizado com sucesso!');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
