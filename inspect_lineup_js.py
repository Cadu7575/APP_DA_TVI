import re

with open('analyze_cf_js.py', 'r') as f:
    pass

import urllib.request
req = urllib.request.Request('https://copafacil.b-cdn.net/main.dart.js?v=1792847003164', headers={'User-Agent': 'Mozilla/5.0'})
js = urllib.request.urlopen(req).read().decode('utf-8', errors='ignore')

# inspect around 2660659
snippet = js[2659000:2663000]
print('Snippet around lineup:')
print(snippet[:2000])
