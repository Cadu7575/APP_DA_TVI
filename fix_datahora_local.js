const admin = require('firebase-admin');
const https = require('https');

const sa = require('./tvi-news-service-account.json');
admin.initializeApp({ credential: admin.credential.cert(sa) });
const db = admin.firestore();

const API_KEY = '4YW3-V7UC-WR5A';

// Category name mapping for display (faseId -> display name)
const CAT_NAMES = {
  // rmjb0 - Varzeano 2025
  '-rmjb0@k6f8': '2ª Divisão',
  '-rmjb0@iffu': '1ª Divisão',
  // jcgq9 - Copa TVitapê 2025
  '-jcgq9@9v8k': 'Sub-9',
  '-jcgq9@ztuy': 'Sub-11',
  '-jcgq9@arqr': 'Sub-13',
  '-jcgq9@gytm': 'Sub-15',
  '-jcgq9@qckh': 'Sub-17',
  '-jcgq9@284z': 'Sub-20',
  '-jcgq9@5mng': 'Livre Masculino',
  '-jcgq9@v3dl': 'Livre Feminino',
  '-jcgq9@5mv4': 'Veterano',
  // 077g4 - Varzeano 2026
  '-077g4@86vf': '1ª Divisão',
  '-077g4@958ly': '2ª Divisão',
  '-077g4@vqo6p': 'Semifinal/Final',
  // 5fqd2 - Copa TVitapê 2026
  '-5fqd2@88imd': 'Sub-9',
  '-5fqd2@t0qyn': 'Sub-11',
  '-5fqd2@v9gyy': 'Sub-13',
  '-5fqd2@1y6x': 'Sub-15',
  '-5fqd2@ah1bq': 'Sub-17',
  '-5fqd2@1rf6i': 'Sub-20',
  '-5fqd2@zda6m': 'Livre Masculino',
  '-5fqd2@fy1s7': 'Livre Feminino',
  '-5fqd2@8ohik': 'Veterano',
};

// All championship -> their category IDs (from Firestore faseId values)
const CAMPS = {
  'copafacil_rmjb0': ['-rmjb0@iffu', '-rmjb0@k6f8'],
  'copafacil_jcgq9': ['-jcgq9@qckh', '-jcgq9@ztuy', '-jcgq9@arqr', '-jcgq9@5mng', '-jcgq9@5mv4', '-jcgq9@9v8k', '-jcgq9@284z', '-jcgq9@v3dl', '-jcgq9@gytm'],
  'copafacil_077g4': ['-077g4@86vf', '-077g4@958ly', '-077g4@vqo6p'],
  'copafacil_5fqd2': ['-5fqd2@1y6x', '-5fqd2@v9gyy', '-5fqd2@zda6m', '-5fqd2@88imd', '-5fqd2@ah1bq', '-5fqd2@fy1s7', '-5fqd2@t0qyn', '-5fqd2@1rf6i', '-5fqd2@8ohik'],
};

function fetchJSON(url) {
  return new Promise((resolve, reject) => {
    https.get(url, { headers: { 'x-api-key': API_KEY } }, (res) => {
      let data = '';
      res.on('data', c => data += c);
      res.on('end', () => {
        try {
          resolve(JSON.parse(data));
        } catch (e) {
          reject(new Error(`JSON parse error for ${url}: ${e.message}\nData: ${data.substring(0,200)}`));
        }
      });
    }).on('error', reject);
  });
}

async function getMatchesFromAPI(catId) {
  try {
    const stages = await fetchJSON(`https://copafacil.com/api2/tournament/${catId}/stages?key=name`);
    if (!stages || !Array.isArray(stages)) return [];
    
    let allMatches = [];
    for (const stage of stages) {
      if (!stage.id) continue;
      try {
        const matches = await fetchJSON(`https://copafacil.com/api2/tournament/${catId}/stage/${stage.id}/matches?key=name`);
        if (Array.isArray(matches)) {
          allMatches = allMatches.concat(matches.map(m => ({ ...m, _stageId: stage.id, _stageName: stage.name })));
        }
      } catch (e) {
        // skip
      }
    }
    return allMatches;
  } catch (e) {
    console.log(`  ⚠ Erro API ${catId}: ${e.message}`);
    return [];
  }
}

async function fixCamp(campId, catIds) {
  console.log(`\n=== ${campId} ===`);
  
  // 1. Fetch all matches from API
  const apiMatchesMap = {};
  for (const catId of catIds) {
    const catName = CAT_NAMES[catId] || catId;
    console.log(`  API: ${catName} (${catId})...`);
    const matches = await getMatchesFromAPI(catId);
    console.log(`    → ${matches.length} partidas`);
    for (const m of matches) {
      apiMatchesMap[m.id] = { ...m, _catId: catId, _catName: catName };
    }
  }
  console.log(`  Total API: ${Object.keys(apiMatchesMap).length}`);
  
  // 2. Read Firestore
  const snap = await db.collection('campeonatos').doc(campId).collection('partidas').get();
  console.log(`  Firestore: ${snap.size} partidas`);
  
  let updated = 0;
  let batch = db.batch();
  let batchCount = 0;
  
  for (const doc of snap.docs) {
    const data = doc.data();
    const update = {};
    
    // Find API match by matchId field or doc ID
    const matchId = data.matchId || doc.id;
    const apiMatch = apiMatchesMap[matchId];
    
    // === FIX dataHora ===
    if (!data.dataHora) {
      if (data.dataTimestamp) {
        update.dataHora = admin.firestore.Timestamp.fromMillis(data.dataTimestamp);
      } else if (apiMatch && apiMatch.datetime) {
        const dt = new Date(apiMatch.datetime);
        if (!isNaN(dt.getTime())) {
          update.dataHora = admin.firestore.Timestamp.fromDate(dt);
        }
      }
    }
    
    // === FIX local ===
    if (!data.local || data.local === '') {
      if (apiMatch && apiMatch.local) {
        update.local = apiMatch.local;
      }
    }
    
    // === FIX categoria (display name) ===
    const faseId = data.faseId;
    const currentCat = data.categoria;
    // If categoria is missing, or is a raw faseId (starts with -), replace with friendly name
    if (!currentCat || currentCat.startsWith('-')) {
      if (CAT_NAMES[faseId]) {
        update.categoria = CAT_NAMES[faseId];
      }
    }
    
    if (Object.keys(update).length > 0) {
      batch.update(doc.ref, update);
      batchCount++;
      updated++;
      
      if (batchCount >= 490) {
        await batch.commit();
        console.log(`    Batch commit: ${updated}...`);
        batch = db.batch();
        batchCount = 0;
      }
    }
  }
  
  if (batchCount > 0) {
    await batch.commit();
  }
  
  console.log(`  ✅ ${updated} partidas atualizadas`);
}

async function main() {
  console.log('🔧 Fix dataHora, local e categoria...\n');
  
  for (const [campId, catIds] of Object.entries(CAMPS)) {
    await fixCamp(campId, catIds);
  }
  
  console.log('\n🎉 Concluído!');
  process.exit(0);
}

main().catch(e => { console.error(e); process.exit(1); });
