const https = require('https');

function fetchPage(url) {
  return new Promise((resolve) => {
    const urlObj = new URL(url);
    https.get({
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' }
    }, (res) => {
      let d = '';
      res.on('data', c => d += c);
      res.on('end', () => resolve({ status: res.statusCode, body: d, headers: res.headers }));
    }).on('error', e => resolve({ error: e.message }));
  });
}

async function main() {
  console.log('Fetching xeh.com.br/tvitape/ ...');
  const r = await fetchPage('https://xeh.com.br/tvitape/');
  console.log('Status:', r.status);

  const body = r.body || '';
  
  // Find iframes
  const iframes = body.match(/<iframe[^>]+>/gi) || [];
  console.log('\n=== IFRAMES ===');
  iframes.forEach(f => console.log(f));

  // Find video sources
  const sources = body.match(/<source[^>]+>/gi) || [];
  console.log('\n=== SOURCES ===');
  sources.forEach(s => console.log(s));

  // Find stream URLs
  const streamRefs = body.match(/https?:\/\/[^"'\s<>]*(?:m3u8|hls|stream|live|rtmp|embed|player)[^"'\s<>]*/gi) || [];
  console.log('\n=== STREAM URLs ===');
  [...new Set(streamRefs)].forEach(u => console.log(u));

  // Find youtube embeds
  const ytRefs = body.match(/youtube\.com\/embed\/[a-zA-Z0-9_-]+/g) || [];
  const ytLive = body.match(/youtube\.com\/live\/[a-zA-Z0-9_-]+/g) || [];
  const ytWatch = body.match(/youtube\.com\/watch\?v=[a-zA-Z0-9_-]+/g) || [];
  console.log('\n=== YOUTUBE REFS ===');
  [...new Set([...ytRefs, ...ytLive, ...ytWatch])].forEach(u => console.log(u));

  // Find JW Player or video.js config
  const jwMatch = body.match(/jwplayer\([^)]+\)\.setup\([^;]+\)/gs) || [];
  jwMatch.forEach(j => console.log('\nJW Player:', j.substring(0, 500)));

  // Find video.js sources
  const vjsMatch = body.match(/videojs[^;]{0,500}/gi) || [];
  vjsMatch.slice(0, 3).forEach(v => console.log('\nVideoJS:', v.substring(0, 300)));

  // Find any script tags with stream data
  const scriptTags = body.match(/<script[^>]*>([\s\S]*?)<\/script>/gi) || [];
  scriptTags.forEach(s => {
    if (s.includes('m3u8') || s.includes('stream') || s.includes('live') || s.includes('hls') || s.includes('rtmp') || s.includes('src')) {
      console.log('\n=== SCRIPT WITH STREAM DATA ===');
      console.log(s.substring(0, 1000));
    }
  });

  // Print a portion of the body to understand structure
  console.log('\n=== BODY (first 4000 chars) ===');
  console.log(body.substring(0, 4000));
}

main().catch(console.error);
