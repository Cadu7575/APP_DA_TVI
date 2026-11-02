const https = require('https');

https.get('https://copafacil.b-cdn.net/main.dart.js?v=1790616177611', (resp) => {
  let data = '';
  resp.on('data', c => data += c);
  resp.on('end', () => {
    const patterns = ['torneios', 'championships', 'ligas', 'leagues', 'eventos', 'partidas', 'jogos', 'equipes', 'teams', 'times', 'players', 'jogadores', 'campeonatos', 'organizadores', 'chaves', 'grupos'];
    patterns.forEach(p => {
      const idx = data.indexOf('"' + p + '"');
      if (idx >= 0) {
        const ctx = data.substring(Math.max(0,idx-100), idx+100).replace(/\n/g,' ');
        console.log('STRING "' + p + '" pos=' + idx + ':');
        console.log('  ' + ctx);
        console.log();
      }
    });
    process.exit(0);
  });
});
