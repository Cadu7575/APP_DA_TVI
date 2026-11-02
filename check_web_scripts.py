import urllib.request
import re

url = 'https://copafacil.com/-jcgq9'
req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
try:
    html = urllib.request.urlopen(req).read().decode('utf-8')
    print('HTML length:', len(html))
    scripts = re.findall(r'<script[^>]*src=[\'"](.*?)[\'"]', html)
    print('Script sources:', scripts)
    inline = re.findall(r'<script[^>]*>(.*?)</script>', html, re.DOTALL)
    for s in inline:
        if 'firebase' in s.lower() or 'config' in s.lower() or 'database' in s.lower():
            print('Inline interesting:', s[:300])
except Exception as e:
    print('Error:', e)
