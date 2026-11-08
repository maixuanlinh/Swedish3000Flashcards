#!/usr/bin/env python3
"""Verify authored content, master provenance, derivatives and packaged assets."""
import hashlib
import json
from pathlib import Path
import zipfile
import argparse

parser = argparse.ArgumentParser()
parser.add_argument('--source-only', action='store_true', help='Verify shared resources without checking an older APK')
args = parser.parse_args()

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
assert {a['wordID'] for a in art} == ids
source = json.loads((root / 'Content/catalog.json').read_text())['entries']
reviewed = json.loads((root / 'Content/artwork.json').read_text())
expected_ids = {w['id'] for w in source if w['contentStatus'] != 'pending' and reviewed.get(w['id'], {}).get('reviewed') is True}
build_input = json.loads((root / 'Content/build-input.json').read_text())
assert ids == set(build_input['reviewedIDs']), 'Study must exactly match reviewed cards captured for this build'
assert ids <= expected_ids, 'Every bundled card must still have authored text and reviewed artwork'
assert {f'sv-{n:04d}' for n in range(1, 3001)} == ids, 'The complete 3000-card collection must be present'
assert all(next(w for w in source if w['id'] == row['id'])['swedish'] == row['swedish'] for row in catalog)
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
assert sum(w['english'].lower().startswith('h') for w in catalog) == 100
assert sum(w['english'].lower().startswith('i') for w in catalog) == 121
assert sum(w['english'].lower().startswith('j') for w in catalog) == 23
assert sum(w['english'].lower().startswith('k') for w in catalog) == 18
assert sum(w['english'].lower().startswith('l') for w in catalog) == 108
assert sum(w['english'].lower().startswith('m') for w in catalog) == 134
assert sum(w['english'].lower().startswith('n') for w in catalog) == 65
assert sum(w['english'].lower().startswith('o') for w in catalog) == 82
assert sum(w['english'].lower().startswith('p') for w in catalog) == 238
assert sum(w['english'].lower().startswith('q') for w in catalog) == 16
assert sum(w['english'].lower().startswith('r') for w in catalog) == 163
assert sum(w['english'].lower().startswith('s') for w in catalog) == 351
for letter, count in {'t':166, 'u':50, 'v':36, 'w':106, 'y':13, 'z':2}.items():
    assert sum(w['english'].lower().startswith(letter) for w in catalog) == count
for row in art:
    for key in ('filename', 'thumbnailFilename'):
        path = resources / 'BundledArtwork' / row[key]
        assert path.parent == resources / 'BundledArtwork'
        assert path.is_file() and path.stat().st_size > 0, path
    relative = Path(reviewed[row['wordID']]['path'])
    assert str(relative).startswith('Content/Artwork/') and '..' not in relative.parts
    master = root / relative
    provenance = json.loads((root / 'Content/Generations' / (row['wordID'] + '.json')).read_text())
    master_hash = hashlib.sha256(master.read_bytes()).hexdigest()
    assert master_hash == provenance['sha256'] == row['masterSHA256'], row['wordID']
    assert hashlib.sha256((resources / 'BundledArtwork' / row['filename']).read_bytes()).hexdigest() == row['bundleSHA256'], row['wordID']
    assert row['encoding'] == 'jpeg-quality-90'
assert {p.name for p in (resources / 'BundledArtwork').glob('sv-*')} == {a['filename'] for a in art}
print(f'PASS: {len(catalog)}/3000 authored Swedish words, bilingual examples; {len(art)} images; 211 A, 152 B, 292 C, 163 D 162 E 155 F, 73 G, 100 H 121 I, 23 J, 18 K, 108 L, 134 M, 65 N, 82 O, 238 P, 16 Q 163 R 351 S, 166 T, 50 U, 36 V, 106 W, 13 Y and 2 Z words.')
apk = root / 'Android/app/build/outputs/apk/debug/app-debug.apk'
if apk.exists() and not args.source_only:
    with zipfile.ZipFile(apk) as archive:
        metadata = [resources / name for name in ('catalog3000.json', 'starter100.json', 'examples3000.json', 'artworkBriefs.json')] + [resources / 'BundledArtwork/manifest.json']
        for path in metadata:
            target = 'assets/' + str(path.relative_to(resources))
            assert hashlib.sha256(path.read_bytes()).digest() == hashlib.sha256(archive.read(target)).digest(), target
        media_path = root / 'MediaDelivery/generated/assets/lesson-media.json'
        assert archive.read('assets/lesson-media.json') == media_path.read_bytes()
        media = json.loads(media_path.read_text())
        assert media['wordCount'] == 3000 and media['recordingCount'] == 8675
        keys = {a['key'] for a in media['assets']}
        for row in art:
            assert all('image/' + row[name] in keys for name in ('filename', 'thumbnailFilename'))
        def recording(language, text):
            return 'audio/' + language + '/' + hashlib.sha256(text.encode()).hexdigest()
        by_id = {e['id']: e for e in examples}
        for word in catalog:
            assert recording('sv-SE', word['swedish']) in keys, word['id']
            assert recording('en-US', word['english']) in keys, word['id']
            assert recording('sv-SE', by_id[word['id']]['sentence']) in keys, word['id']
        assert not any(k.startswith('audio/fi-FI/') for k in keys)
        for pack in media['packs']:
            target = 'assets/' + pack['file']
            if target in archive.namelist():
                data = archive.read(target)
                assert len(data) == pack['bytes'] and hashlib.sha256(data).hexdigest() == pack['sha256']
            else:
                assert not pack['starter'], 'Starter pack missing from APK'
        assert not any(n.endswith(('.onnx', '.jpg', '.webp', '.mp3')) and n.startswith('assets/') for n in archive.namelist()), 'Only packed starter media belongs in this lightweight build'
    print('PASS: APK metadata matches shared iOS resources; all 3000 images and 9000 audio positions mapped; starter packs verified.')
else:
    print('APK asset-hash verification not performed; rebuild Android before checking its package.')
