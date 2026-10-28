#!/usr/bin/env python3
"""Verify authored content, master provenance, derivatives and packaged assets."""
import hashlib
import json
from pathlib import Path
import zipfile

root = Path(__file__).resolve().parents[2]
resources = root / 'Resources'
catalog_data = json.loads((resources / 'catalog3000.json').read_text())
catalog = catalog_data['entries']
examples = json.loads((resources / 'examples3000.json').read_text())
art = json.loads((resources / 'BundledArtwork/manifest.json').read_text())
starter = json.loads((resources / 'starter100.json').read_text())
ids = {w['id'] for w in catalog}
assert 0 < len(catalog) == len(ids) == len(examples) == catalog_data['entryCount'] <= 3000
assert catalog_data['targetCount'] == 3000
assert {e['id'] for e in examples} == ids
assert {a['wordID'] for a in art} <= ids
assert all(w['id'] == f"sv-{w['sourceID']:04d}" and w['swedish'].strip() and 'finnish' not in w for w in catalog)
assert len({e['id'] for e in examples}) == len(examples)
assert len({e['wordID'] for e in art}) == len(art)
assert {w['id'] for w in starter} <= ids
assert all(e['sentence'].strip() and e['sentenceEnglish'].strip() for e in examples)
assert sum(w['english'].lower().startswith('a') for w in catalog) == 211
assert sum(w['english'].lower().startswith('b') for w in catalog) == 152
assert sum(w['english'].lower().startswith('c') for w in catalog) == 292
assert sum(w['english'].lower().startswith('d') for w in catalog) == 163
assert sum(w['english'].lower().startswith('e') for w in catalog) == 162
assert sum(w['english'].lower().startswith('f') for w in catalog) == 155
assert sum(w['english'].lower().startswith('g') for w in catalog) == 73
for row in art:
    for key in ('filename', 'thumbnailFilename'):
        path = resources / 'BundledArtwork' / row[key]
        assert path.parent == resources / 'BundledArtwork'
        assert path.is_file() and path.stat().st_size > 0, path
    master = root / 'Content/Artwork' / (row['wordID'] + '.png')
    provenance = json.loads((root / 'Content/Generations' / (row['wordID'] + '.json')).read_text())
    master_hash = hashlib.sha256(master.read_bytes()).hexdigest()
    assert master_hash == provenance['sha256'] == row['masterSHA256'], row['wordID']
    assert hashlib.sha256((resources / 'BundledArtwork' / row['filename']).read_bytes()).hexdigest() == row['bundleSHA256'], row['wordID']
    assert row['encoding'] == 'jpeg-quality-90'
assert {p.name for p in (resources / 'BundledArtwork').glob('sv-*')} == {a['filename'] for a in art}
print(f'PASS: {len(catalog)}/3000 authored Swedish words, bilingual examples; {len(art)} images; 211 A, 152 B, 292 C, 163 D 162 E 155 F and 73 G words.')
apk = root / 'Android/app/build/outputs/apk/debug/app-debug.apk'
if apk.exists():
    with zipfile.ZipFile(apk) as archive:
        for path in [resources / name for name in ('catalog3000.json', 'starter100.json', 'examples3000.json', 'artworkBriefs.json')] + list((resources / 'BundledArtwork').glob('*')):
            if path.is_file():
                target = 'assets/' + str(path.relative_to(resources))
                assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(archive.read(target)).digest(), target
    print('PASS: every packaged vocabulary/metadata/image file matches iOS source SHA-256.')
else:
    print('APK asset-hash verification pending: compile :app:assembleDebug first.')
