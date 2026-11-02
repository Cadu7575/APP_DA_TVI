const https = require('https');
https.get('https://copafacil.com/5fqd2', {
  headers: {'User-Agent':'Mozilla/5.0 (Windows NT 10.0; Win64; x64) Chrome/120.0.0.0'}
}, res => {
  let d = '';
  res.on('data', c => d += c);
  res.on('end', () => {
    // Procura dados SSR do Next.js
    const m = d.match(/<script id="__NEXT_DATA__" type="application\/json">([\s\S]*?)<\/script>/);
    if (m) {
      try {
        const json = JSON.parse(m[1]);
        console.log('NEXT_DATA encontrado!');
        console.log(JSON.stringify(json, null, 2).substring(0, 5000));
      } catch(e) { console.log('Erro parse NEXT_DATA:', e.message); }
    } else {
      console.log('Sem NEXT_DATA. Analisando HTML...');
      // Procura props/state
      const props = d.match(/self\.__next_f\.push\(\[.*?\]\)/g);
      if (props) console.log('Next props:', props.slice(0,5));
      
      // Procura referencias a Firebase ou IDs
      const firebaseRefs = d.match(/firestore|firebase|championship|campeonato/gi);
      console.log('Firebase refs:', firebaseRefs ? firebaseRefs.slice(0,10) : 'nenhuma');
      
      // Procura JSON embedded
      const jsonBlocks = d.match(/\{[^<]{200,}\}/g);
      if (jsonBlocks) {
        jsonBlocks.slice(0,3).forEach((b, i) => {
          try {
            const parsed = JSON.parse(b);
            console.log('JSON block ' + i + ':', JSON.stringify(parsed).substring(0, 200));
          } catch {}
        });
      }
      
      console.log('\nHTML (primeiros 2000 chars):');
      console.log(d.substring(0, 2000));
    }
  });
}).on('error', console.error);
