// Ultima tentativa: os campeonatos da CopáFácil têm URLs publicas.
// Na screenshot vemos: Copa TVitapê 2026, Varzeano Itapetininga 2026, etc.
// O ID do campeonato provavelmente aparece na URL quando voce abre cada um.
// Vamos tentar acessar via HTTP os IDs codificados em base32/nanoid que
// aparecem na pagina publica do campeonato.

// Alternativa: tenta buscar via Firestore REST sem auth (dados publicos)
const https = require('https');

function get(url) {
  return new Promise(res => {
    https.get(url, resp => {
      let d = '';
      resp.on('data', c => d += c);
      resp.on('end', () => res({ status: resp.statusCode, body: d }));
    }).on('error', e => res({ error: e.message }));
  });
}

async function main() {
  // Os campeonatos da CopáFácil têm paginas publicas com slug
  // Tenta slugs baseados nos nomes vistos na screenshot
  const slugs = [
    'copa-tvitape-2026', 'copa-tv-itape-2026', 'copa-tvitape-futsal-2026',
    'copa-tvitape-futsal', 'varzeano-itapetininga-2026', 'varzeano-itapetininga',
    'copa-tvitape-2025', 'varzeano-itapetininga-2025',
    'copa-tvitape', 'varzeano-2026',
  ];

  for (const slug of slugs) {
    // URL publica do campeonato na CopáFácil
    const url = `https://copafacil.com/c/${slug}`;
    const r = await get(url);
    if (r.status === 200) {
      // Extrai possivel ID do conteudo
      const idMatch = r.body.match(/[A-Za-z0-9_-]{15,25}/);
      console.log(`✅ ${url} (${r.status}) - possivel ID:`, idMatch ? idMatch[0] : 'nao encontrado');
      console.log('   HTML preview:', r.body.substring(0, 200).replace(/\n/g,' '));
    } else {
      console.log(`  ${slug}: HTTP ${r.status}`);
    }
  }

  // Tenta tambem via Firestore REST sem auth - campeonatos publicos
  const fsBase = 'https://firestore.googleapis.com/v1/projects/copafacil-web/databases/(default)/documents';
  for (const slug of slugs.slice(0, 3)) {
    const r = await get(`${fsBase}/championships/${slug}`);
    const body = JSON.parse(r.body || '{}');
    if (body.name && !body.error) {
      console.log(`\n✅ Firestore championships/${slug}:`, JSON.stringify(body).substring(0, 300));
    }
  }

  process.exit(0);
}
main().catch(e => { console.error(e.message); process.exit(1); });
