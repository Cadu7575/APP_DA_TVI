// CopáFácil tem paginas de SSG/SSR para SEO
// URL: https://copafacil.com/c/{slug}  - o slug é exatamente o ID do campeonato no Firestore
// Mas o conteudo é renderizado via Flutter (client-side) então nao tem HTML util
//
// NOVA ABORDAGEM: usa o Firestore SDK com autenticacao para ler diretamente
// pelo ID do documento, que é o mesmo que o slug da URL
// Os campeonatos visiveis na screenshot do usuario logado são:
// - Copa TVitapê 2026 
// - Varzeano Itapetininga 2026
// - Copa TVitapê 2025
// - Varzeano Itapetininga 2025
//
// Os IDs reais no Firestore são os slugs no campo "slug" ou o proprio ID do documento

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');
const { getFirestore, doc, getDoc, collection, getDocs, query, where, limit } = require('firebase/firestore');

const app = initializeApp({
  apiKey: 'AIzaSyDbR0mRSSb554WadsJgfOivSXLET84IIR0',
  authDomain: 'copafacil-web.firebaseapp.com',
  projectId: 'copafacil-web',
}, 'cf');
const auth = getAuth(app);
const db = getFirestore(app);

// Slugs possiveis dos campeonatos vistos na screenshot
const CHAMPIONSHIP_SLUGS = [
  'copa-tvitape-2026',
  'copa-tv-itape-2026',
  'varzeano-itapetininga-2026',
  'copa-tvitape-2025',
  'varzeano-itapetininga-2025',
  'copa-tvitape-futsal-2026',
  'copa-tvitape-futsal-2025',
  'copa-tvitape',
  'varzeano-itapetininga',
  'copa_tvitape_2026',
  'varzeano_itapetininga_2026',
];

// Colecoes possiveis
const COLLECTIONS = ['championships', 'campeonatos', 'c', 'champ', 'torneios'];

async function main() {
  const cred = await signInWithEmailAndPassword(auth, 'lalomoraes@copafacil.com', 'L@lO2@25');
  const uid = cred.user.uid;
  console.log('UID:', uid);

  // Tenta buscar cada campeonato pelo slug como ID do documento
  for (const col of COLLECTIONS) {
    for (const slug of CHAMPIONSHIP_SLUGS) {
      try {
        const d = await getDoc(doc(db, col, slug));
        if (d.exists()) {
          console.log(`\n✅ ENCONTROU: /${col}/${slug}`);
          console.log('Campos:', Object.keys(d.data()).join(', '));
          console.log('Dados:', JSON.stringify(d.data()).substring(0, 500));
        }
      } catch(e) {
        // Silencioso - documento nao existe
      }
    }
  }
  
  // Tenta query por nome
  for (const col of COLLECTIONS) {
    for (const field of ['name', 'nome', 'title', 'titulo']) {
      for (const nome of ['Copa TVitapê 2026', 'Varzeano Itapetininga 2026', 'Copa TVitapê']) {
        try {
          const snap = await getDocs(query(collection(db, col), where(field, '==', nome), limit(3)));
          if (!snap.empty) {
            console.log(`\n✅ QUERY ${col} onde ${field}=="${nome}": ${snap.size} docs`);
            snap.forEach(d => console.log('  ID:', d.id, '| campos:', Object.keys(d.data()).join(',')));
          }
        } catch(e) {}
      }
    }
  }

  // Por ultimo: tenta buscar o doc do usuario com lista de campeonatos por referencia
  // Na CopáFácil, o usuario pode ter um array de referencias de campeonatos
  try {
    const d = await getDoc(doc(db, 'users', uid));
    if (d.exists()) {
      console.log('\nDOC users/', uid, ':', JSON.stringify(d.data()));
    }
  } catch(e) {}

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
