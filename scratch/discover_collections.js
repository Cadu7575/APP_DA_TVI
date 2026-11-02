/**
 * discover_collections.js  
 * Lista todas as colecoes raiz do Firestore e testa o slug como ID
 */
const https = require('https');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const EMAIL = 'lalomoraes@copafacil.com';
const SENHA = 'L@lO2@25';
const PROJECT = 'copafacil-web';
const BASE = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

function post(hostname, path, body, headers = {}) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request({ hostname, path, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data), ...headers }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch { resolve({ status: res.statusCode, body: d }); } });
    });
    req.on('error', () => resolve({ status: 0 }));
    req.write(data); req.end();
  });
}

function get(url, token) {
  return new Promise(resolve => {
    const headers = token ? { Authorization: `Bearer ${token}` } : {};
    https.get(url, { headers }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve({ status: res.statusCode, body: JSON.parse(d) }); } catch { resolve({ status: res.statusCode, body: d.substring(0, 200) }); } });
    }).on('error', () => resolve({ status: 0 }));
  });
}

function parseValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields || {}).map(([k, vv]) => [k, parseValue(vv)]));
  if (v.arrayValue) return (v.arrayValue.values || []).map(parseValue);
  if (v.referenceValue !== undefined) return v.referenceValue;
  return null;
}

async function main() {
  // 1. Obtém token
  const auth = await post('identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithPassword?key=${API_KEY}`,
    { email: EMAIL, password: SENHA, returnSecureToken: true });
  
  if (!auth.body?.idToken) { console.log('Erro auth:', auth.body); return; }
  const TOKEN = auth.body.idToken;
  const UID = auth.body.localId;
  console.log(`Token OK! UID: ${UID}\n`);

  // 2. Lista TODAS as colecoes raiz via REST
  console.log('=== LISTANDO TODAS AS COLECOES ===');
  const listCols = await post('firestore.googleapis.com',
    `/v1/projects/${PROJECT}/databases/(default)/documents:listCollectionIds`,
    { pageSize: 100 },
    { Authorization: `Bearer ${TOKEN}` }
  );
  
  if (listCols.body?.collectionIds) {
    console.log('Colecoes encontradas:', listCols.body.collectionIds);
  } else {
    console.log('listCollectionIds:', listCols.status, JSON.stringify(listCols.body).substring(0, 200));
  }

  // 3. Testa slug como ID em TODAS as colecoes possiveis
  console.log('\n=== TESTANDO SLUG 5fqd2 EM TODAS AS COLECOES ===');
  const colsParaTestar = [
    'championships', 'campeonatos', 'tournaments', 'c', 'champ',
    'leagues', 'ligas', 'competitions', 'competicoes', 'events', 'eventos',
    'cups', 'copas', 'groups', 'grupos', 'slugs', 'urls', 'aliases',
    'public', 'publico', 'data', 'content', 'pages',
  ];

  for (const col of colsParaTestar) {
    const r = await get(`${BASE}/${col}/5fqd2`, TOKEN);
    if (r.status === 200 && r.body?.fields) {
      console.log(`\n✅ ENCONTRADO: ${col}/5fqd2`);
      const fields = Object.fromEntries(Object.entries(r.body.fields).map(([k, v]) => [k, parseValue(v)]));
      console.log('Campos:', JSON.stringify(fields).substring(0, 500));
    } else if (r.status !== 404) {
      console.log(`${col}/5fqd2: ${r.status}`);
    }
  }

  // 4. Tenta buscar via slug como campo
  console.log('\n=== QUERY POR CAMPO SLUG/ID ===');
  for (const col of ['championships', 'campeonatos', 'c', 'tournaments']) {
    for (const field of ['slug', 'shortId', 'shortUrl', 'id', 'urlId', 'publicId', 'shareId', 'code', 'alias', 'key']) {
      const qbody = JSON.stringify({
        structuredQuery: {
          from: [{ collectionId: col }],
          where: { fieldFilter: { field: { fieldPath: field }, op: 'EQUAL', value: { stringValue: '5fqd2' } } },
          limit: 5
        }
      });
      const r = await post('firestore.googleapis.com',
        `/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`,
        JSON.parse(qbody),
        { Authorization: `Bearer ${TOKEN}` }
      );
      const docs = (Array.isArray(r.body) ? r.body : []).filter(x => x.document);
      if (docs.length > 0) {
        console.log(`\n✅ QUERY ${col} onde ${field}==5fqd2: ${docs.length} docs!`);
        const d = docs[0].document;
        const fields = Object.fromEntries(Object.entries(d.fields || {}).map(([k, v]) => [k, parseValue(v)]));
        console.log('ID:', d.name.split('/').pop());
        console.log('Campos:', JSON.stringify(fields).substring(0, 400));
      }
    }
  }

  // 5. Tenta ler usuarios em colecao alternativa
  console.log('\n=== BUSCANDO USUARIO EM COLECOES ALTERNATIVAS ===');
  const userCols = ['users', 'members', 'organizers', 'accounts', 'profiles', 'admins', 'pessoas', 'clientes'];
  for (const col of userCols) {
    const r = await get(`${BASE}/${col}/${UID}`, TOKEN);
    if (r.status === 200 && r.body?.fields) {
      console.log(`\n✅ Usuario em ${col}/${UID}:`);
      const fields = Object.fromEntries(Object.entries(r.body.fields).map(([k, v]) => [k, parseValue(v)]));
      console.log(JSON.stringify(fields, null, 2).substring(0, 1000));
    }
  }

  console.log('\nDone.');
}

main().catch(console.error);
