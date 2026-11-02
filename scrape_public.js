const https = require('https');
const fs = require('fs');

// Pega os links de JS embarcados na pagina e baixa-os procurando dados de times
function get(url) {
  return new Promise(resolve => {
    https.get(url, {headers:{'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}}, res=>{
      let d='';
      res.on('data', c => d += c);
      res.on('end', () => resolve({s: res.statusCode, d, headers: res.headers}));
    }).on('error', () => resolve({s:0, d:'', headers:{}}));
  });
}

(async()=>{
  // Pega a pagina publica do campeonato que deveria ter SSR ou estado
  const r = await get('https://copafacil.com/varzeano2025');
  console.log('Page size:', r.d.length);
  
  // Salva para analise
  fs.writeFileSync('varzeano_page.html', r.d);
  console.log('Salvo varzeano_page.html');
  
  // Extrai links de JS
  const jsLinks = r.d.match(/src="(https?:\/\/[^"]+\.js[^"]*)"/g);
  const bundleLinks = r.d.match(/href="(https?:\/\/[^"]+\.js[^"]*)"/g);
  
  console.log('JS scripts:', jsLinks ? jsLinks.slice(0,5) : 'nenhum');
  
  // Procura dados embutidos
  const dataMatches = r.d.match(/__NEXT_DATA__|__NUXT__|__INITIAL_STATE__|window\._data/g);
  console.log('Dados embutidos:', dataMatches);
  
  // Procura qualquer JSON grande na pagina
  const bigJson = r.d.match(/\{[^{}]{500,}\}/g);
  if(bigJson) {
    console.log('JSON grande encontrado, tamanho:', bigJson[0].length);
  }
  
  // Ver o que tem na pagina
  console.log('\nPrimeiros 2000 chars do HTML:');
  console.log(r.d.substring(0, 2000));
})().catch(console.error);
