/**
 * read_rtdb.js
 * Lê dados do Firebase Realtime Database da CopáFácil
 * Caminho descoberto: /events/-5fqd2/list_evt
 */

const https = require('https');
const admin = require('firebase-admin');
const fs = require('fs');

const API_KEY = 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0';
const EMAIL = 'lalomoraes@copafacil.com';
const SENHA = 'L@lO2@25';

// URLs possiveis do RTDB da CopáFácil
const RTDB_URLS = [
  'copafacil-web-default-rtdb.firebaseio.com',
  'copafacil-web.firebaseio.com',
  'copafacil-default-rtdb.firebaseio.com',
];

// IDs conhecidos dos campeonatos (slug da URL)
// Formato RTDB: negativo (push ID pode comecar com -)
const CAMP_SLUGS = ['5fqd2']; // Adicionar os outros quando o usuario clicar

function post(hostname, path, body) {
  return new Promise(resolve => {
    const data = JSON.stringify(body);
    const req = https.request({ hostname, path, method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Content-Length': Buffer.byteLength(data) }
    }, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => { try { resolve(JSON.parse(d)); } catch { resolve({}); } });
    });
    req.on('error', () => resolve({}));
    req.write(data); req.end();
  });
}

function rtdbGet(hostname, path, token) {
  return new Promise(resolve => {
    const url = `https://${hostname}${path}.json?auth=${token}`;
    https.get(url, res => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => {
        try { resolve({ status: res.statusCode, body: JSON.parse(d) }); }
        catch { resolve({ status: res.statusCode, body: d.substring(0, 200) }); }
      });
    }).on('error', () => resolve({ status: 0, body: null }));
  });
}

const dadosColetados = {};

async function main() {
  // 1. Obtém token de auth
  console.log('Obtendo token...');
  const auth = await post('identitytoolkit.googleapis.com',
    `/v1/accounts:signInWithPassword?key=${API_KEY}`,
    { email: EMAIL, password: SENHA, returnSecureToken: true });

  if (!auth.idToken) { console.log('Erro auth:', JSON.stringify(auth)); return; }
  const TOKEN = auth.idToken;
  const UID = auth.localId;
  console.log(`Token OK! UID: ${UID}\n`);

  // 2. Testa cada URL do RTDB
  for (const rtdbUrl of RTDB_URLS) {
    console.log(`\n=== Testando ${rtdbUrl} ===`);
    
    // Testa raiz
    const root = await rtdbGet(rtdbUrl, '', TOKEN);
    if (root.status === 200 && root.body && root.body !== 'null') {
      console.log(`RTDB raiz OK! Chaves: ${typeof root.body === 'object' ? Object.keys(root.body).slice(0, 20).join(', ') : root.body}`);
    }
    
    // Testa caminho /events/-5fqd2 (descoberto no console do browser)
    for (const slug of CAMP_SLUGS) {
      const paths = [
        `/events/-${slug}`,
        `/events/${slug}`,
        `/championships/-${slug}`,
        `/championships/${slug}`,
        `/campeonatos/-${slug}`,
        `/campeonatos/${slug}`,
        `/c/-${slug}`,
        `/c/${slug}`,
      ];
      
      for (const path of paths) {
        const r = await rtdbGet(rtdbUrl, path, TOKEN);
        if (r.status === 200 && r.body && r.body !== 'null') {
          console.log(`\n✅ ENCONTRADO: ${rtdbUrl}${path}`);
          const keys = typeof r.body === 'object' ? Object.keys(r.body) : [];
          console.log(`Chaves: ${keys.join(', ')}`);
          if (keys.length > 0) {
            console.log('Dados:', JSON.stringify(r.body).substring(0, 500));
            dadosColetados[slug] = { url: rtdbUrl, path, data: r.body };
          }
        } else {
          const msg = r.body && typeof r.body === 'string' ? r.body.substring(0, 50) : r.status;
          console.log(`  ${path}: ${msg}`);
        }
      }
    }
    
    // Testa path /events com auth
    const eventsPath = `/events`;
    const eventsR = await rtdbGet(rtdbUrl, eventsPath, TOKEN);
    if (eventsR.status === 200 && eventsR.body && eventsR.body !== 'null') {
      console.log(`\n✅ /events OK!`);
      const keys = typeof eventsR.body === 'object' ? Object.keys(eventsR.body) : [];
      console.log(`Total eventos: ${keys.length}`);
      keys.slice(0, 5).forEach(k => console.log(`  ${k}`));
      dadosColetados['_events_root'] = { url: rtdbUrl, path: eventsPath, data: eventsR.body };
    }
    
    // Testa /users/{uid}
    const userPath = `/users/${UID}`;
    const userR = await rtdbGet(rtdbUrl, userPath, TOKEN);
    if (userR.status === 200 && userR.body && userR.body !== 'null') {
      console.log(`\n✅ Usuario encontrado!`);
      console.log(JSON.stringify(userR.body).substring(0, 500));
    }
  }
  
  // 3. Tenta paths adicionais no RTDB que faz sentido
  console.log('\n=== Caminhos alternativos ===');
  const rtdb = RTDB_URLS[0];
  const pathsExtra = [
    `/championships`,
    `/campeonatos`,
    `/c`,
    `/organizers/${UID}`,
    `/organizer/${UID}`,
    `/admin/${UID}`,
  ];
  
  for (const path of pathsExtra) {
    const r = await rtdbGet(rtdb, path, TOKEN);
    if (r.status === 200 && r.body && r.body !== 'null') {
      console.log(`✅ ${path}: ${JSON.stringify(r.body).substring(0, 200)}`);
    } else {
      console.log(`  ${path}: ${r.status}`);
    }
  }
  
  // 4. Salva o que coletou
  fs.writeFileSync('rtdb_data.json', JSON.stringify(dadosColetados, null, 2), 'utf-8');
  console.log('\nSalvo em rtdb_data.json');
  
  if (Object.keys(dadosColetados).length > 0) {
    console.log('\n🎉 Dados encontrados! Importando para TVI...');
    await importarParaTVI(dadosColetados);
  } else {
    console.log('\n⚠️  Nenhum dado capturado ainda.');
    console.log('Preciso do ID completo do campeonato no RTDB.');
    console.log('\nNo console do Chrome, na pagina copafacil.com/5fqd2, cole:');
    console.log('copy(JSON.stringify(window.firebase?.apps))');
    console.log('ou cole o snippet de interceptacao de fetch.');
  }
}

async function importarParaTVI(dados) {
  const cred = admin.credential.cert(require('./tvi-news-service-account.json'));
  admin.initializeApp({ credential: cred, projectId: 'tvi-news' });
  const db = admin.firestore();
  
  for (const [slug, info] of Object.entries(dados)) {
    if (slug.startsWith('_')) continue;
    const camp = info.data;
    const nome = camp.name || camp.nome || camp.title || `Campeonato ${slug}`;
    const docId = `copafacil_${slug}`;
    
    await db.collection('campeonatos').doc(docId).set({
      nome, esporte: camp.sport || camp.esporte || 'futebol',
      status: 'encerrado', organizadorId: 'lalomoraes_migrado',
      organizadorNome: 'MM Eventos', migradoDeCopafacil: true,
      copafacilSlug: slug, criadoEm: admin.firestore.FieldValue.serverTimestamp(),
    });
    console.log(`✓ ${nome}`);
  }
  console.log('Importação concluída!');
  process.exit(0);
}

main().catch(console.error);
