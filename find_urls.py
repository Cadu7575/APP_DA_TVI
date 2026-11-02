import urllib.request
import re

url = 'https://copafacil.com/-jcgq9'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    matches = re.findall(r'https?://[^\s"\'<>]+', html)
    for m in set(matches):
        if 'copafacil' in m or 'firebase' in m or 'api' in m:
            print(m)
except Exception as e:
    print('Error:', e)
