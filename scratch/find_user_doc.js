// Abordagem final: busca os IDs dos campeonatos publicos da CopáFácil
// pela pagina publica do organizador lalomoraes
// URL: https://copafacil.com/o/lalomoraes  ou similar

const https = require('https');
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, getDoc, collection, getDocs } = require('firebase/firestore');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);
const db = getFirestore(app);

async function fetchUrl(url, token) {
  return new Promise((res) => {
    const opts = token ? { headers: { 'Authorization': 'Bearer ' + token } } : {};
    https.get(url, opts, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => res({ status: resp.statusCode, body: data }));
    }).on('error', e => res({ error: e.message }));
  });
}

function extractValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.timestampValue !== undefined) return v.timestampValue;
  if (v.nullValue !== undefined) return null;
  if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k,vv]) => [k, extractValue(vv)]));
  if (v.arrayValue) return (v.arrayValue.values || []).map(extractValue);
  return null;
}

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  const token = await cred.user.getIdToken();
  console.log('UID:', uid);

  // Tenta buscar o doc do usuario direto via SDK (pode ter permissao de ler o proprio)
  try {
    const d = await getDoc(doc(db, 'users', uid));
    if (d.exists()) {
      console.log('\nDOC users/', uid, ':', JSON.stringify(d.data()));
    }
  } catch(e) {}

  // Tenta pegar lista de campeonatos que o usuario segue/pertence via array
  // buscando no doc do usuario campo como "championships", "campeonatos", "ids"
  const userCollections = ['users', 'organizers', 'organizadores', 'perfis', 'accounts'];
  for (const c of userCollections) {
    try {
      const d = await getDoc(doc(db, c, uid));
      if (d.exists()) {
        const data = d.data();
        console.log(`\nDOC ${c}/${uid}:`, JSON.stringify(data).substring(0, 600));
        // Se tem lista de campeonatos, pegar cada um
        const champIds = data.championships || data.campeonatos || data.championshipIds || [];
        if (champIds.length > 0) {
          console.log('IDs de campeonatos:', champIds);
        }
      }
    } catch(e) {}
  }

  // Tenta buscar pagina publica do organizador
  const publicUrls = [
    'https://copafacil.com/o/lalomoraes',
    'https://copafacil.com/organizador/lalomoraes',
    'https://copafacil.com/organizer/lalomoraes',
  ];
  for (const url of publicUrls) {
    const r = await fetchUrl(url);
    if (r.status === 200 && r.body.length > 200) {
      // Busca IDs de campeonatos no HTML
      const ids = r.body.match(/[A-Za-z0-9]{15,25}/g) || [];
      if (ids.length > 0) {
        console.log(`\n${url}: encontrei ${ids.length} tokens potenciais de ID`);
        console.log('Primeiros 10:', ids.slice(0,10));
      }
    }
  }

  // Ultima tentativa: busca o doc do organizador pelo campo "username"
  // Na CopáFácil o usuario tem um "username" = lalomoraes
  const fsBase = 'https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)';
  const queryBody = JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: 'users' }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'username' },
          op: 'EQUAL',
          value: { stringValue: 'lalomoraes' }
        }
      },
      limit: 5
    }
  });

  const r = await new Promise(res => {
    const req = https.request(`${fsBase}/documents:runQuery`, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(queryBody)
      }
    }, resp => {
      let d = '';
      resp.on('data', c => d += c);
      resp.on('end', () => res(d));
    });
    req.write(queryBody);
    req.end();
  });
  
  const arr = JSON.parse(r);
  const docs = (Array.isArray(arr) ? arr : []).filter(x => x.document);
  console.log('\nQuery users onde username=lalomoraes:', docs.length, 'docs');
  if (docs.length > 0) {
    const fields = docs[0].document.fields;
    const obj = Object.fromEntries(Object.entries(fields).map(([k,v]) => [k, extractValue(v)]));
    console.log('Doc:', JSON.stringify(obj).substring(0, 800));
    
    // Pega IDs de campeonatos do doc
    const champIds = obj.championships || obj.campeonatos || obj.championshipIds || obj.myChampionships || [];
    console.log('Championship IDs:', champIds);
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
