const admin = require('firebase-admin');
const sa = require('./tvi-news-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

// 1. Mapeamento confirmado da API da Copa Fácil para a 2ª Divisão do Varzeano 2026 (-077g4@vqo6p)
const MAP_077G4 = {
  '-OwZ6CfQ1-5J2RvazWSv': { name: 'Aguia Paulista', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6CfQ1-5J2RvazWSv.jpg?alt=media&token=1&m=1785241158946' },
  '-OwZ6CfQ1-': { name: 'Aguia Paulista', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6CfQ1-5J2RvazWSv.jpg?alt=media&token=1&m=1785241158946' },

  '-OwZ6GYTBcUHM0JfgiIo': { name: 'Amigos de Itapê', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6GYTBcUHM0JfgiIo.jpg?alt=media&token=1&m=1785336144762' },
  '-OwZ6GYTBc': { name: 'Amigos de Itapê', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6GYTBcUHM0JfgiIo.jpg?alt=media&token=1&m=1785336144762' },

  '-OwZ6K5unjLZQ1DveZlu': { name: 'Bela Vista Futebol Arte (B)', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6K5unjLZQ1DveZlu.jpg?alt=media&token=1&m=1787664683558' },
  '-OwZ6K5unj': { name: 'Bela Vista Futebol Arte (B)', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6K5unjLZQ1DveZlu.jpg?alt=media&token=1&m=1787664683558' },

  '-OwZ6Ox1fAK_pf9S11Pi': { name: 'Clube dos Veteranos Itapetiningano', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6Ox1fAK_pf9S11Pi.jpg?alt=media&token=1&m=1787665240612' },
  '-OwZ6Ox1fA': { name: 'Clube dos Veteranos Itapetiningano', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6Ox1fAK_pf9S11Pi.jpg?alt=media&token=1&m=1787665240612' },

  '-OwZ6TqHbKsZKU9mVe8j': { name: 'Fami Fut', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6TqHbKsZKU9mVe8j.jpg?alt=media&token=1&m=1787067352892' },
  '-OwZ6TqHbK': { name: 'Fami Fut', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6TqHbKsZKU9mVe8j.jpg?alt=media&token=1&m=1787067352892' },

  '-OwZ6V_I8eXdKO0PtKml': { name: 'Horizonte FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6V_I8eXdKO0PtKml.jpg?alt=media&token=1&m=1786392068346' },
  '-OwZ6V_I8e': { name: 'Horizonte FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6V_I8eXdKO0PtKml.jpg?alt=media&token=1&m=1786392068346' },

  '-OwZ6Zy907lrCoxkkR9A': { name: 'Inter Galácticos', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6Zy907lrCoxkkR9A.jpg?alt=media&token=1&m=1786390181393' },
  '-OwZ6Zy907': { name: 'Inter Galácticos', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6Zy907lrCoxkkR9A.jpg?alt=media&token=1&m=1786390181393' },

  '-OwZ6btdz9vujZVpaaZQ': { name: 'Jardim Nova Era', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6btdz9vujZVpaaZQ.jpg?alt=media&token=1&m=1785246103781' },
  '-OwZ6btdz9': { name: 'Jardim Nova Era', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6btdz9vujZVpaaZQ.jpg?alt=media&token=1&m=1785246103781' },

  '-OwZ6a8wvjsVkBDjNd2D': { name: 'Dragões da Vila', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6a8wvjsVkBDjNd2D.jpg' },
  '-OwZ6a8wvj': { name: 'Dragões da Vila', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6a8wvjsVkBDjNd2D.jpg' },

  '-OwZ6REsGTgFFyJEuWmr': { name: 'Milionários', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6REsGTgFFyJEuWmr.jpg' },
  '-OwZ6REsGT': { name: 'Milionários', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6REsGTgFFyJEuWmr.jpg' },

  '-OwZ6fQZcz7GH5PYqqFu': { name: 'Troia FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6fQZcz7GH5PYqqFu.jpg' },
  '-OwZ6fQZcz': { name: 'Troia FC', photo: 'https://copafacil-storage.b-cdn.net/events%2F-077g4%2Fvqo6p%2Fteams%2F-OwZ6fQZcz7GH5PYqqFu.jpg' }
};

async function run() {
  const c = 'copafacil_077g4';
  console.log(`=== Corrigindo ${c} ===`);

  // Partidas
  const pSnap = await db.collection('campeonatos').doc(c).collection('partidas').get();
  const pBatch = db.batch();
  let pCount = 0;

  pSnap.docs.forEach(doc => {
    const d = doc.data();
    const updates = {};

    const tA = MAP_077G4[d.timeAId] || MAP_077G4[d.timeANome];
    if (tA) {
      if (d.timeANome !== tA.name) updates.timeANome = tA.name;
      if (!d.timeALogo && tA.photo) updates.timeALogo = tA.photo;
    }

    const tB = MAP_077G4[d.timeBId] || MAP_077G4[d.timeBNome];
    if (tB) {
      if (d.timeBNome !== tB.name) updates.timeBNome = tB.name;
      if (!d.timeBLogo && tB.photo) updates.timeBLogo = tB.photo;
    }

    if (Object.keys(updates).length > 0) {
      pBatch.update(doc.ref, updates);
      pCount++;
    }
  });

  if (pCount > 0) {
    await pBatch.commit();
    console.log(`Partidas 077g4 atualizadas: ${pCount}`);
  }

  // Classificacao
  const cSnap = await db.collection('campeonatos').doc(c).collection('classificacao').get();
  const cBatch = db.batch();
  let cCount = 0;

  cSnap.docs.forEach(doc => {
    const d = doc.data();
    const updates = {};

    const t = MAP_077G4[d.timeId] || MAP_077G4[d.timeNome];
    if (t) {
      if (d.timeNome !== t.name) updates.timeNome = t.name;
    }

    if (Object.keys(updates).length > 0) {
      cBatch.update(doc.ref, updates);
      cCount++;
    }
  });

  if (cCount > 0) {
    await cBatch.commit();
    console.log(`Classificação 077g4 atualizada: ${cCount}`);
  }

  // Colecao Times
  for (const [id, info] of Object.entries(MAP_077G4)) {
    if (id.length > 15) {
      await db.collection('campeonatos').doc(c).collection('times').doc(id).set({
        id: id,
        nome: info.name,
        escudoUrl: info.photo,
        logoUrl: info.photo,
        campeonatoId: c,
        categoria: '2ª Divisão',
        criadoEm: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
  }

  console.log('Times inseridos/atualizados na colecao "times"!');
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
