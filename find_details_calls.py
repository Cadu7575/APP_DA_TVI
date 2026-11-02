import urllib.request
import re

req = urllib.request.Request('https://copafacil.b-cdn.net/main.dart.js?v=1792847003164', headers={'User-Agent': 'Mozilla/5.0'})
js = urllib.request.urlopen(req).read().decode('utf-8', errors='ignore')

matches = [m.start() for m in re.finditer(re.escape('.j("details")'), js)]
print(f'details matches: {len(matches)}')
for idx in matches:
    print('---')
    print(js[max(0, idx - 100):min(len(js), idx + 250)])
