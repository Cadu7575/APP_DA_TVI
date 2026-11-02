import urllib.request
import json
import re

url = 'https://copafacil.com/api2/tournament/-jcgq9@5mng/rankings/ART'
req = urllib.request.Request(url, headers={'x-api-key': '4YW3-V7UC-WR5A'})
try:
    content = urllib.request.urlopen(req).read().decode('utf-8')
    fixed = re.sub(r'"title"\s*:\s*"Scorers"', '"title":"Scorers",', content)
    data = json.loads(fixed)
    players = data.get('players', [])
    print(f'Players count: {len(players)}')
    for p in players[:10]:
        print(f"Nome: {p.get('name')} | Time: {p.get('teamName')} | Gols: {p.get('data')}")
except Exception as e:
    print('Error:', e)
