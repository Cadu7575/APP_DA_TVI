import urllib.request
import json
import re

cats = [
    '-jcgq9@9v8k', '-jcgq9@ztuy', '-jcgq9@arqr', '-jcgq9@gytm',
    '-jcgq9@qckh', '-jcgq9@284z', '-jcgq9@5mng', '-jcgq9@v3dl', '-jcgq9@5mv4',
    '-077g4@86vf', '-077g4@958ly', '-077g4@vqo6p',
    '-rmjb0@k6f8', '-rmjb0@iffu',
    '-5fqd2@1y6x', '-5fqd2@v9gyy', '-5fqd2@zda6m', '-5fqd2@88imd',
    '-5fqd2@ah1bq', '-5fqd2@fy1s7', '-5fqd2@t0qyn', '-5fqd2@1rf6i', '-5fqd2@8ohik'
]

total_players = 0
for cat in cats:
    url = f'https://copafacil.com/api2/tournament/{cat}/rankings/ART'
    req = urllib.request.Request(url, headers={'x-api-key': '4YW3-V7UC-WR5A'})
    try:
        content = urllib.request.urlopen(req).read().decode('utf-8')
        fixed = re.sub(r'"title"\s*:\s*"Scorers"', '"title":"Scorers",', content)
        data = json.loads(fixed)
        pls = data.get('players', [])
        total_players += len(pls)
        if len(pls) > 0:
            print(f'{cat}: {len(pls)} artilheiros encontrados')
    except Exception as e:
        pass

print(f'Total de jogadores encontrados nos rankings: {total_players}')
