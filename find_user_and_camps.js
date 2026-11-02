/**
 * find_user_and_camps.js
 * Tenta ler o documento do usuario que contem os IDs dos campeonatos
 */

const https = require('https');

const TOKEN = "eyJhbGciOiJSUzI1NiIsImtpZCI6IjgwMWQ0YTIwNzMwN2I0ZjM1NmFjZGI4NWNhNzE3ZWU3YmEwZGJmN2UiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJodHRwczovL3NlY3VyZXRva2VuLmdvb2dsZS5jb20vY29wYWZhY2lsLXdlYiIsImF1ZCI6ImNvcGFmYWNpbC13ZWIiLCJhdXRoX3RpbWUiOjE3ODc3MDMxMjcsInVzZXJfaWQiOiJPUU1sN2V1STZrVGpQdTlUZEg2YzNOam0ySHcxIiwic3ViIjoiT1FNbDdldUk2a1RqUHU5VGRINmMzTmptMkh3MSIsImlhdCI6MTc5MDg4NTYyNSwiZXhwIjoxNzkwODg5MjI1LCJlbWFpbCI6ImxhbG9tb3JhZXNAY29wYWZhY2lsLmNvbSIsImVtYWlsX3ZlcmlmaWVkIjpmYWxzZSwiZmlyZWJhc2UiOnsiaWRlbnRpdGllcyI6eyJlbWFpbCI6WyJsYWxvbW9yYWVzQGNvcGFmYWNpbC5jb20iXX0sInNpZ25faW5fcHJvdmlkZXIiOiJwYXNzd29yZCJ9fQ.Fno9xwTmQEIQF0CH2NJRz8Y2IdS23JitrcUq2K_Iuzj7VzAkMDP8S2K1ojFSJF7q2A3Tc-ZiQ2OQLOIzKEIYyQPRKqFro36qoCpBXKQRSGYfSwFl7sb0An-g9GDD-SxjV9ob0O_72ctxajLqhQs80rfJiYg1lAipl69W-qk70r-1jmlFcTwFLojVYlQQyDadZrJbDWAGm9tw5vJVjJHvVaBhfpZKx4V0IZ1KNwZd633rJ0h7AVmRmbZhWGu8k0-9HYOSlYbKN7kOm5I2q2fElHCmPCLBpn9K8OF4s4QgEB2O6nYj-qYb7D8TVIbr95IWbqB81l8EN-OdA1m32XO8ow";
const UID = "OQMl7euI6kTjPu9TdH6c3Njm2Hw1";
const BASE = `https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents`;

function get(path) {
  return new Promise(resolve => {
    const url = `${BASE}/${path}`;
    https.get(url, { headers: { Authorization: `Bearer ${TOKEN}` } }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d.substring(0, 200) }); }
      });
    }).on('error', e => resolve({ status: 0, body: e.message }));
  });
}

function parseValue(v) {
  if (!v) return null;
  if (v.stringValue !== undefined) return v.stringValue;
  if (v.integerValue !== undefined) return parseInt(v.integerValue);
  if (v.booleanValue !== undefined) return v.booleanValue;
  if (v.mapValue) return Object.fromEntries(Object.entries(v.mapValue.fields||{}).map(([k,vv])=>[k,parseValue(vv)]));
  if (v.arrayValue) return (v.arrayValue.values||[]).map(parseValue);
  if (v.referenceValue !== undefined) return v.referenceValue;
  return null;
}

async function main() {
  console.log('Buscando documento do usuario e IDs dos campeonatos...\n');

  // 1. Tenta ler documento do usuario em varias colecoes
  const userPaths = [
    `users/${UID}`,
    `members/${UID}`,
    `organizers/${UID}`,
    `organizadores/${UID}`,
    `profiles/${UID}`,
    `accounts/${UID}`,
    `admins/${UID}`,
  ];

  for (const path of userPaths) {
    const { status, body } = await get(path);
    if (status === 200 && body.fields) {
      console.log(`\nACHOU: ${path}`);
      const campos = Object.fromEntries(Object.entries(body.fields).map(([k,v]) => [k, parseValue(v)]));
      console.log('Campos:', JSON.stringify(campos, null, 2));

      // Procura IDs de campeonatos nos campos
      const campIds = [];
      for (const [k, v] of Object.entries(campos)) {
        if (Array.isArray(v)) {
          v.forEach(item => {
            if (typeof item === 'string' && item.length > 10) campIds.push(item);
          });
        }
        if (typeof v === 'string' && (k.toLowerCase().includes('camp') || k.toLowerCase().includes('champ'))) {
          campIds.push(v);
        }
      }
      if (campIds.length > 0) {
        console.log('\nPossiveis IDs de campeonatos:', campIds);
      }
    } else {
      console.log(`${path}: ${status} ${status===404?'(nao existe)':status===403?'(sem permissao)':'(vazio)'}`);
    }
  }

  // 2. Tenta sub-colecoes do usuario
  console.log('\n--- Sub-colecoes do usuario ---');
  const subCols = ['championships', 'campeonatos', 'tournaments', 'myChampionships'];
  for (const sub of subCols) {
    const { status, body } = await get(`users/${UID}/${sub}`);
    if (body?.documents?.length > 0) {
      console.log(`users/${UID}/${sub}: ${body.documents.length} docs!`);
      body.documents.forEach(d => {
        const f = Object.fromEntries(Object.entries(d.fields||{}).map(([k,v])=>[k,parseValue(v)]));
        console.log(`  ${d.name.split('/').pop()}:`, JSON.stringify(f).substring(0, 150));
      });
    } else {
      console.log(`users/${UID}/${sub}: ${status} ${body?.documents?.length===0?'(vazio)':'(sem acesso)'}`);
    }
  }

  // 3. Tenta IDs de campeonatos baseados nos nomes conhecidos
  console.log('\n--- Tentando IDs baseados nos nomes ---');
  // CopáFácil provavelmente usa nanoid ou uuid como ID
  // Mas pode usar slug como ID do documento
  const slugsPossiveis = [
    'copa-tvitape-2026', 'copa_tvitape_2026', 'copaTvitape2026',
    'varzeano-itapetininga-2026', 'varzeano_itapetininga_2026',
    'copa-tvitape-2025', 'varzeano-itapetininga-2025',
    'copa-tv-itape-2026', 'varzeano-2026', 'copa-tvitape',
  ];

  for (const col of ['championships', 'campeonatos']) {
    for (const slug of slugsPossiveis) {
      const { status, body } = await get(`${col}/${slug}`);
      if (status === 200 && body.fields) {
        console.log(`\n✓ ENCONTRADO: ${col}/${slug}`);
        const f = Object.fromEntries(Object.entries(body.fields).map(([k,v])=>[k,parseValue(v)]));
        console.log(JSON.stringify(f, null, 2).substring(0, 500));
      }
    }
  }

  // 4. Tenta buscar via collectionGroup query (todos championships em qualquer nivel)
  console.log('\n--- CollectionGroup query ---');
  const cgUrl = `${BASE}:runQuery`;
  const cgBody = JSON.stringify({
    structuredQuery: {
      from: [{ collectionId: 'championships', allDescendants: true }],
      where: {
        fieldFilter: {
          field: { fieldPath: 'uid' },
          op: 'EQUAL',
          value: { stringValue: UID }
        }
      },
      limit: 50
    }
  });

  await new Promise(resolve => {
    const req = https.request(cgUrl, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${TOKEN}`,
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(cgBody)
      }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try {
          const arr = JSON.parse(d);
          const docs = (Array.isArray(arr) ? arr : []).filter(x => x.document);
          if (docs.length > 0) {
            console.log(`CollectionGroup championships: ${docs.length} docs!`);
            docs.forEach(x => console.log(`  ${x.document.name.split('/').pop()}`));
          } else {
            console.log('CollectionGroup: nenhum resultado');
            if (d.substring(0, 200).includes('error')) console.log('Erro:', d.substring(0, 200));
          }
        } catch { console.log('CollectionGroup error'); }
        resolve();
      });
    });
    req.write(cgBody);
    req.end();
  });

  // 5. O app provavelmente carrega os campeonatos do usuario via Cloud Function ou direto
  // Vamos tentar a Cloud Function endpoint
  console.log('\n--- Cloud Functions ---');
  const cfBase = 'https://us-central1-copafacil-web.cloudfunctions.net';
  const endpoints = [
    '/getUserChampionships', '/getMyChampionships', '/listChampionships',
    '/championships', '/api/championships', '/api/user/championships',
  ];
  for (const ep of endpoints) {
    await new Promise(resolve => {
      const url = `${cfBase}${ep}`;
      https.get(url, { headers: { Authorization: `Bearer ${TOKEN}` } }, res => {
        let d = '';
        res.on('data', c => d += c);
        res.on('end', () => {
          if (res.statusCode !== 404) {
            console.log(`${ep}: ${res.statusCode} → ${d.substring(0, 100)}`);
          }
          resolve();
        });
      }).on('error', () => resolve());
    });
  }

  console.log('\nDone.');
}

main().catch(console.error);
