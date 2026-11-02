// Tenta descobrir a estrutura via URL publica dos campeonatos na CopáFácil
// URL tipica: https://copafacil.com/c/{slug-do-campeonato}
// Ou talvez: https://copafacil.com/championship/{id}
// Buscamos nos JS links para entender os IDs

const https = require('https');

// Busca o JS e extrai IDs de campeonatos hardcoded ou padroes de rota
https.get('https://copafacil.b-cdn.net/main.dart.js?v=1790616177611', (resp) => {
  let data = '';
  resp.on('data', c => data += c);
  resp.on('end', () => {
    // Procura pelos nomes dos campeonatos mencionados no JS
    const nomes = ['Copa TVitap', 'Varzeano', 'Itapetininga', 'copa_tvitape', 'varzeano'];
    nomes.forEach(n => {
      let idx = 0;
      while (true) {
        idx = data.indexOf(n, idx);
        if (idx < 0) break;
        console.log(`"${n}" em ${idx}:`, data.substring(Math.max(0,idx-100), idx+150).replace(/\n/g,' '));
        console.log();
        idx += n.length;
      }
    });

    // Busca padroes de ID no formato Firebase (20 chars alfanumericos)
    // Contexto: routes, navigation paths
    const routePatterns = data.match(/\/c\/([A-Za-z0-9_-]{10,30})/g) || [];
    const champRoutes = data.match(/\/championship\/([A-Za-z0-9_-]{10,30})/g) || [];
    console.log('Rotas /c/:', [...new Set(routePatterns)].slice(0,10));
    console.log('Rotas /championship/:', [...new Set(champRoutes)].slice(0,10));

    process.exit(0);
  });
});
