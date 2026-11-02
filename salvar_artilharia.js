const fs = require('fs');
const admin = require('firebase-admin');
const sa = require('./tvi-news-service-account.json');

admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

async function run() {
  const text = fs.readFileSync('c:/Users/Carlos/Desktop/TVI/artilharia_rmjb0.txt', 'utf-8');
  const fixed = text.replace('"title":"Scorers"', '"title":"Scorers",');
  const data = JSON.parse(fixed);
  console.log('Total artilheiros:', data.players.length);

  let count = 0;
  for (const p of data.players) {
    const docId = (p.name || 'player').toLowerCase().replace(/[^a-z0-9]/g, '_');
    const gols = p.tableData && p.tableData.length ? (parseInt(p.tableData[0].value) || 0) : 0;
    await db.collection('campeonatos').doc('copafacil_rmjb0').collection('artilharia').doc(docId).set({
      nome: p.name || '',
      jogadorNome: p.name || '',
      timeNome: p.teamName || '',
      timeId: p.teamId || '',
      gols: gols,
      posicao: p.position || 1
    }, { merge: true });
    count++;
  }
  console.log('Artilharia salva no Varzeano 2025:', count);
  process.exit(0);
}

run().catch(e => { console.error(e); process.exit(1); });
