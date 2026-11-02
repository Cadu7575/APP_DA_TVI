import urllib.request
import json
import re

def get_scorers(cat):
    url = f'https://copafacil.com/api2/tournament/{cat}/rankings/ART'
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
        return mapping
    except Exception as e:
        print(f"Error for {cat}: {e}")
        return {}

cats = [
    '-jcgq9@9v8k', '-jcgq9@ztuy', '-jcgq9@arqr', '-jcgq9@gytm',
    '-jcgq9@qckh', '-jcgq9@284z', '-jcgq9@5mng', '-jcgq9@v3dl', '-jcgq9@5mv4',
    '-077g4@86vf', '-077g4@958ly', '-077g4@vqo6p'
]

all_teams = {}
for cat in cats:
    res = get_scorers(cat)
    all_teams.update(res)

with open('artilharia_extracted_teams.json', 'w', encoding='utf-8') as f:
    json.dump(all_teams, f, indent=2, ensure_ascii=False)

print(f"Total teams extracted from scorers: {len(all_teams)}")
for k, v in all_teams.items():
    if 'OWLA' in k or 'OWLG' in k:
        print(k, '->', v)
