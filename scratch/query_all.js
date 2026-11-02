// Abordagem direta: usa o Firestore SDK com as regras do usuario logado
// Os campeonatos publicos devem estar acessiveis por qualquer usuario autenticado
// Vamos buscar pelos IDs dos campeonatos que aparecem na pagina do usuario
// usando a API grafica da copafacil

const https = require('https');
const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, getDoc, collection, getDocs, query, where, limit, orderBy } = require('firebase/firestore');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);
const db = getFirestore(app);

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  console.log('UID:', uid);

  // Na CopáFácil o Firestore provavelmente tem regras que:
  // - Permitem leitura de championship onde uid == request.auth.uid
  // - Vamos tentar buscar diretamente pelo documento com ID = uid
  
  // Primeiro, vamos ver quais colecoes raiz existem tentando algumas combinacoes
  // O Flutter app acessa: collection('championships').where('uid', '==', uid)
  // Mas pode ser que o campo se chame diferente
  
  // Tenta listar todas as subcollecoes possiveis em: users/{uid}/championships
  const subPaths = [
    ['users', uid, 'championships'],
    ['users', uid, 'campeonatos'],
    ['organizers', uid, 'championships'],
    ['organizers', uid, 'campeonatos'],
    ['organizadores', uid, 'campeonatos'],
  ];
  
  for (const [col, id, sub] of subPaths) {
    try {
      const snap = await getDocs(collection(db, col, id, sub));
      if (!snap.empty) {
        console.log(`\nACHOU: /${col}/${id}/${sub} - ${snap.size} docs`);
        snap.forEach(d => {
          console.log('  -', d.id, '|', JSON.stringify(d.data()).substring(0, 200));
        });
      } else {
        // Colecao existe mas vazia, ou sem permissao
      }
    } catch(e) {
      if (!e.message.includes('NOT_FOUND') && !e.message.includes('permission')) {
        console.log(`${col}/${id}/${sub} erro: ${e.message}`);
      }
    }
  }

  // Tenta query direta em championships com varios campos UID
  const champsCollection = collection(db, 'championships');
  for (const field of ['uid', 'userId', 'organizerId', 'organizadorId', 'owner', 'ownerId', 'authorId']) {
    try {
      const snap = await getDocs(query(champsCollection, where(field, '==', uid), limit(10)));
      if (!snap.empty) {
        console.log(`\nACHOU em championships onde ${field}==${uid}: ${snap.size} docs`);
        snap.forEach(d => {
          console.log('  -', d.id, JSON.stringify(d.data()).substring(0, 300));
        });
      }
    } catch(e) {}
  }
  
  // Tenta query sem filtro para ver se retorna algo
  try {
    const snap = await getDocs(query(collection(db, 'championships'), limit(100)));
    if (!snap.empty) {
      console.log(`\nchampionships SEM FILTRO: ${snap.size} docs`);
      // Filtra pelo uid
      const meus = snap.docs.filter(d => {
        const data = d.data();
        return Object.values(data).includes(uid);
      });
      console.log('  Meus (por valor uid):', meus.length);
      
      // Mostra todos para inspecionar
      snap.forEach(d => {
        const data = d.data();
        console.log('  -', d.id, '| campos:', Object.keys(data).join(','), '| amostra:', JSON.stringify(data).substring(0,150));
      });
    }
  } catch(e) {
    console.log('championships sem filtro erro:', e.message);
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
