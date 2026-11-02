import urllib.request
import re

req = urllib.request.Request('https://copafacil.b-cdn.net/main.dart.js?v=1792847003164', headers={'User-Agent': 'Mozilla/5.0'})
js = urllib.request.urlopen(req).read().decode('utf-8', errors='ignore')
print('JS length:', len(js))

# Look for patterns like "api2/" or endpoints
endpoints = set(re.findall(r'api2/[a-zA-Z0-9_\-/]+', js))
print('Endpoints found:', len(endpoints))
for ep in sorted(endpoints)[:30]:
    print(' ', ep)

# Look for match detail or sumula
terms = ['events/', 'match/', 'matches/', 'lineup', 'escalacao', 'lances', 'events%2F']
for t in terms:
    occs = [m.start() for m in re.finditer(re.escape(t), js, re.IGNORECASE)]
    print(f"Term '{t}': {len(occs)} occurrences")
    for idx in occs[:3]:
        snippet = js[max(0, idx - 60):min(len(js), idx + 100)]
        print(f"   [{idx}]: {repr(snippet)}")
