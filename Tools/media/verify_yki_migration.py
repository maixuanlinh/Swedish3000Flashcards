#!/usr/bin/env python3
"""Verify canonical YKI pages and legacy URL compatibility after migration."""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[2]
NEW = 'https://yki.essaykingapp.com/swedish3000/'
OLD = 'https://essaykingapp.com/swedish3000/'
HEADERS = {'User-Agent': 'SwedishCards/1.0 (hosting verification)', 'Accept-Encoding': 'identity'}

def get(url, headers=None):
    return urllib.request.urlopen(urllib.request.Request(url, headers={**HEADERS, **(headers or {})}), timeout=40)

def sha(data):
    return hashlib.sha256(data).hexdigest()

pages = []
for name in ['index.html', 'support.html', 'privacy.html']:
    expected = (ROOT / 'Website' / name).read_bytes()
    with get(NEW + name) as response:
        assert response.status == 200 and response.url == NEW + name
        assert response.read() == expected, name
    with get(OLD + name) as response:
        assert response.url == NEW + name, f'Legacy page not redirected: {name}'
        assert response.read() == expected
    pages.append({'url': NEW + name, 'sha256': sha(expected), 'legacyRedirectVerified': True})
for name in ['index.html', 'support.html', 'privacy.html']:
    expected = (ROOT.parent / 'Website/yki3000' / name).read_bytes()
    with get('https://yki.essaykingapp.com/' + name) as response:
        assert response.read() == expected, 'YKI root page differs: ' + name
manifest = json.loads((ROOT / 'MediaDelivery/public/v1/manifest.json').read_bytes())
packs = {p['file']: p for p in manifest['packs']}
asset = next(a for a in manifest['assets'] if a['key'].startswith('image/') and not packs[a['pack']]['starter'])
start, end = asset['offset'], asset['offset'] + asset['bytes'] - 1
with get(OLD + 'v1/' + asset['pack'], {'Range': f'bytes={start}-{end}'}) as response:
    assert response.url == NEW + 'v1/' + asset['pack']
    assert response.status == 206
    assert response.headers['Content-Range'] == f"bytes {start}-{end}/{packs[asset['pack']]['bytes']}"
    assert sha(response.read()) == asset['sha256']
result = {'canonicalBase': NEW, 'pages': pages, 'rootHomepageAndFinnishPagesMatch': True,
          'legacyImageRangeRedirectVerified': asset['key']}
out = ROOT / 'Verification/ReleasePreparation/yki-domain-migration.json'
out.write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
