import urllib.request
import re

req = urllib.request.Request('https://copafacil.b-cdn.net/main.dart.js?v=1792847003164', headers={'User-Agent': 'Mozilla/5.0'})
js = urllib.request.urlopen(req).read().decode('utf-8', errors='ignore')

# Search for Cartão or Gol or Amarelo or Vermelho
for word in ['Cartão Amarelo', 'Cartão Vermelho', 'Gol', 'Substituição']:
    pos = js.find(word)
    print(f"Word '{word}' at: {pos}")
    if pos != -1:
        print(repr(js[max(0, pos-150):min(len(js), pos+200)]))
