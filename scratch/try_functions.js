// Abordagem alternativa: usa a API HTTP da CopáFácil diretamente
// O app Flutter web faz chamadas para o Firestore usando a SDK,
// mas tambem pode ter Cloud Functions. Vamos tentar interceptar via REST
// com o ID token do usuario logado

const https = require('https');
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);

async function post(url, body, token) {
  return new Promise((res) => {
    const bodyStr = JSON.stringify(body);
    const parsed = new URL(url);
    const req = https.request({
      hostname: parsed.hostname,
      path: parsed.pathname + parsed.search,
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr)
      }
    }, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => { 
        try { res({ status: resp.statusCode, body: JSON.parse(data) }); } 
        catch(e) { res({ status: resp.statusCode, body: data.substring(0, 500) }); }
      });
    });
    req.on('error', e => res({ error: e.message }));
    req.write(bodyStr);
    req.end();
  });
}

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  const token = await cred.user.getIdToken();
  console.log('UID:', uid);

  // Cloud Function para buscar campeonatos do organizador
  const cfUrl = 'https://us-central1-copafacil-web.cloudfunctions.net/';
  
  // Tenta endpoints comuns
  const endpoints = ['getChampionships', 'getUserChampionships', 'getCampeonatos', 'listChampionships'];
  for (const ep of endpoints) {
    const r = await post(cfUrl + ep, { uid }, token);
    if (r.status !== 404 && r.status !== 403) {
      console.log(ep + ':', JSON.stringify(r).substring(0, 300));
    }
  }

  // Tenta via Firestore REST com collectionGroup - busca partidas/times/jogadores
  // para descobrir o ID dos campeonatos do usuario
  const fsBase = 'https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)';
  
  // Busca collectionGroup de 'teams' com filter por organizerId
  const queryBody = {
    structuredQuery: {
      from: [{ collectionId: 'teams', allDescendants: true }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'organizerId' },
          op: 'EQUAL',
          value: { stringValue: uid }
        }
      },
      limit: 5
    }
  };
  
  const r2 = await post(`${fsBase}/documents:runQuery`, queryBody, token);
  console.log('\ncollectionGroup teams por organizerId:', JSON.stringify(r2.body).substring(0, 500));

  // Tenta buscar diretamente os IDs conhecidos das screenshots
  // Na URL da copafacil, o campeonato costuma ter ID no formato: xxxxxxxxxxxxxxxxxxx
  // Vamos tentar via collectionGroup sem filtro (pode ter permissao de leitura propria)
  const queryBody2 = {
    structuredQuery: {
      from: [{ collectionId: 'championships', allDescendants: true }],
      limit: 5
    }
  };
  const r3 = await post(`${fsBase}/documents:runQuery`, queryBody2, token);
  const arr = Array.isArray(r3.body) ? r3.body : [];
  const docs = arr.filter(x => x.document);
  console.log('\ncollectionGroup championships sem filtro:', docs.length, 'docs');
  if (docs.length > 0) {
    console.log('Primeiro:', JSON.stringify(docs[0]).substring(0, 500));
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
