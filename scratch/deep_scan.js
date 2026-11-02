// Busca os IDs dos campeonatos do usuario via pagina publica da CopáFácil
// As URLs publicas sao: copafacil.com/c/{id-do-campeonato}
// Vamos buscar via a API REST do Firestore tentando IDs que aparecem na screenshot
const https = require('https');
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);

async function firestoreGet(path, token) {
  return new Promise((res) => {
    const url = `https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents/${path}`;
    const req = https.request(url, {
      headers: { 'Authorization': 'Bearer ' + token }
    }, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => { try { res(JSON.parse(data)); } catch(e) { res(null); } });
    });
    req.on('error', () => res(null));
    req.end();
  });
}

async function runQuery(token, body) {
  return new Promise((res) => {
    const url = 'https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents:runQuery';
    const bodyStr = JSON.stringify(body);
    const req = https.request(url, {
      method: 'POST',
      headers: {
        'Authorization': 'Bearer ' + token,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(bodyStr)
      }
    }, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => { try { res(JSON.parse(data)); } catch(e) { res([]); } });
    });
    req.on('error', () => res([]));
    req.write(bodyStr);
    req.end();
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

function docToObj(doc) {
  if (!doc || !doc.fields) return {};
  return Object.fromEntries(Object.entries(doc.fields).map(([k,v]) => [k, extractValue(v)]));
}

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  const token = await cred.user.getIdToken();
  console.log('UID:', uid);

  // Tenta listar todas as colecoes de raiz via REST (sem filtro)
  const collections = ['championships', 'campeonatos', 'torneios', 'ligas', 'organizadores', 
                        'organizacoes', 'organizations', 'clubs', 'clubes', 'users', 'profiles'];
  
  for (const col of collections) {
    const r = await firestoreGet(`${col}?pageSize=3`, token);
    if (r && r.documents && r.documents.length > 0) {
      console.log(`\nCOLECAO "${col}" TEM DADOS! (${r.documents.length} docs)`);
      const obj = docToObj(r.documents[0]);
      console.log('Campos:', Object.keys(obj).join(', '));
      console.log('Amostra:', JSON.stringify(obj).substring(0, 300));
    } else if (r && r.error) {
      // Permission denied - mas a colecao EXISTE
      if (!r.error.message.includes('NOT_FOUND')) {
        console.log(`"${col}": Permission denied (colecao EXISTE mas sem acesso)`);
      }
    }
  }

  // Tenta busca sem colecao especifica no usuario
  const userPaths = [
    `users/${uid}`,
    `profiles/${uid}`,
    `organizers/${uid}`,
  ];
  for (const p of userPaths) {
    const r = await firestoreGet(p, token);
    if (r && r.fields) {
      const obj = docToObj(r);
      console.log(`\nDOC "${p}":`, JSON.stringify(obj).substring(0, 500));
    }
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
