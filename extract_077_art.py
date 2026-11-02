import urllib.request
import json
import re

url = 'https://copafacil.com/api2/tournament/-077g4@vqo6p/rankings/ART'
req = urllib.request.Request(url, headers={'x-api-key': '4YW3-V7UC-WR5A'})
try:
    content = urllib.request.urlopen(req).read().decode('utf-8')
    fixed = re.sub(r'"title"\s*:\s*"Scorers"', '"title":"Scorers",', content)
    data = json.loads(fixed)
    mapping = {}
    for p in data.get('players', []):
        tid = p.get('teamId')
        tname = p.get('teamName')
        tphoto = p.get('teamPhoto')
        if tid and tname:
            mapping[tid] = {'name': tname, 'photo': tphoto}
    print(json.dumps(mapping, indent=2, ensure_ascii=False))
except Exception as e:
    print('Error:', e)
