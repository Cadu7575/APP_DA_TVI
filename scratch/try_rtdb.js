// Abordagem via Realtime Database (RTDB) com caminhos do usuario
// O RTDB URL é: https://copafacil-web.firebaseio.com/
// Vamos tentar paths do usuario especificamente

const https = require('https');
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  databaseURL: 'https://copafacil-web.firebaseio.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);

async function rtdb(path, token, shallow = true) {
  return new Promise((res) => {
    const url = `https://copafacil-web.firebaseio.com/${path}.json?auth=${token}${shallow ? '&shallow=true' : ''}`;
    https.get(url, (resp) => {
      let data = '';
      resp.on('data', c => data += c);
      resp.on('end', () => { 
        try { res({ status: resp.statusCode, body: JSON.parse(data) }); } 
        catch(e) { res({ status: resp.statusCode, body: data }); }
      });
    }).on('error', e => res({ error: e.message }));
  });
}

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  const token = await cred.user.getIdToken();
  console.log('UID:', uid);

  // Caminhos no RTDB para tentar
  const paths = [
    // Caminhos do usuario
    `users/${uid}`,
    `user/${uid}`,
    `users/${uid}/championships`,
    `users/${uid}/campeonatos`,
    `organizers/${uid}`,
    `organizadores/${uid}`,
    `profiles/${uid}`,
    // Caminhos publicos
    'championships',
    'campeonatos',
    'public/championships',
    // Por username
    'usernames/lalomoraes',
    'slugs/lalomoraes',
  ];

  for (const p of paths) {
    const r = await rtdb(p, token, true);
    if (r.body && r.body !== null && !r.body.error && JSON.stringify(r.body) !== 'null') {
      console.log(`\n✅ DADOS EM "/${p}":`);
      console.log(JSON.stringify(r.body).substring(0, 500));
    } else if (r.body && r.body.error && !r.body.error.includes('denied') && !r.body.error.includes('null')) {
      console.log(`  ${p}: ${r.body.error}`);
    }
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
